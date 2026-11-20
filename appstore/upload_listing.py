"""Fill the Kinledger 1.0 App Store page from appstore/metadata, appstore/listing.json and the store screenshots.

Runs from .github/workflows/appstore-listing.yml. Safe to run again: text is overwritten with the files,
screenshots are replaced only when they changed, and price and availability are set only once.

Not possible through the API, so still done in App Store Connect: App Privacy (answers in app-privacy.md).
"""
import hashlib
import json
import os
import sys
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
from create_subscriptions import Client, describe, fail, problems, ref  # noqa: E402

HERE = Path(__file__).parent
CONFIG = json.loads((HERE / "listing.json").read_text())
METADATA = HERE / "metadata"
SHOTS = Path(os.environ.get("SHOTS_DIR", "shots"))

AGE_ENUMS = [
    "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
    "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
    "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
    "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic",
]
AGE_FLAGS = [
    "gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "parentalControls",
    "ageAssurance", "userGeneratedContent", "advertising", "healthOrWellnessTopics",
]


def text(locale: str, name: str) -> str | None:
    path = METADATA / locale / f"{name}.txt"
    return path.read_text().strip() if path.exists() else None


def patch(asc: Client, kind: str, ident: str, what: str, attributes: dict | None = None,
          relationships: dict | None = None, version: str = "v1") -> bool:
    data: dict = {"type": kind, "id": ident}
    if attributes:
        data["attributes"] = attributes
    if relationships:
        data["relationships"] = {name: {"data": value} for name, value in relationships.items()}
    response = asc.request("PATCH", f"/{version}/{kind}/{ident}", data=json.dumps({"data": data}))
    if response.status_code == 200:
        return True
    problems.append(f"{what}: {describe(response)}")
    print(f"  ! {what}: {describe(response)}")
    return False


def get_one(asc: Client, path: str) -> dict | None:
    response = asc.request("GET", path)
    if response.status_code == 200:
        return response.json().get("data")
    if response.status_code == 404:
        return None
    fail(f"GET {path}", response)
    return None


def upsert(asc: Client, kind: str, existing: dict | None, attributes: dict, parent: tuple[str, dict], what: str) -> dict | None:
    """Update the row if it exists, otherwise create it under its parent."""
    if existing:
        patch(asc, kind, existing["id"], what, attributes)
        return existing
    return asc.create(kind, attributes, {parent[0]: parent[1]}, what)


def md5(data: bytes) -> str:
    return hashlib.md5(data).hexdigest()


def upload(asc: Client, kind: str, parent: tuple[str, dict], path: Path, what: str) -> bool:
    """Reserve, upload in the parts Apple asks for, then commit with the checksum."""
    data = path.read_bytes()
    asset = asc.create(kind, {"fileName": path.name, "fileSize": len(data)}, {parent[0]: parent[1]}, what)
    if asset is None:
        return False
    for op in asset["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        part = data[op["offset"]: op["offset"] + op["length"]]
        response = requests.request(op["method"], op["url"], headers=headers, data=part, timeout=120)
        if response.status_code >= 300:
            problems.append(f"{what}: upload HTTP {response.status_code}")
            print(f"  ! {what}: upload HTTP {response.status_code}")
            return False
    return patch(asc, kind, asset["id"], f"{what} (commit)", {"uploaded": True, "sourceFileChecksum": md5(data)})


def app_info_and_texts(asc: Client, app_id: str) -> None:
    infos, _ = asc.get_all(f"/v1/apps/{app_id}/appInfos")
    live = {"READY_FOR_DISTRIBUTION", "READY_FOR_SALE"}
    info = next((i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) not in live), infos[0])
    info_id = info["id"]

    print("Categories")
    patch(asc, "appInfos", info_id, "categories", relationships={
        "primaryCategory": ref("appCategories", CONFIG["primaryCategory"]),
        "secondaryCategory": ref("appCategories", CONFIG["secondaryCategory"]),
    })

    print("Age rating")
    declaration = get_one(asc, f"/v1/appInfos/{info_id}/ageRatingDeclaration")
    if declaration:
        present = declaration.get("attributes", {})
        answers = {key: "NONE" for key in AGE_ENUMS if key in present}
        answers |= {key: False for key in AGE_FLAGS if key in present}
        answers |= {key: value for key, value in CONFIG["ageRating"].items() if key in present}
        patch(asc, "ageRatingDeclarations", declaration["id"], "age rating", answers)

    print("Name, subtitle and privacy link")
    have, _ = asc.get_all(f"/v1/appInfos/{info_id}/appInfoLocalizations")
    by_locale = {item["attributes"]["locale"]: item for item in have}
    for locale_dir in sorted(METADATA.iterdir()):
        locale = locale_dir.name
        attributes = {"name": text(locale, "name"), "subtitle": text(locale, "subtitle"),
                      "privacyPolicyUrl": text(locale, "privacy_url")}
        attributes = {k: v for k, v in attributes.items() if v}
        if locale not in by_locale:
            attributes["locale"] = locale
        upsert(asc, "appInfoLocalizations", by_locale.get(locale), attributes,
               ("appInfo", ref("appInfos", info_id)), f"app info {locale}")


def version(asc: Client, app_id: str) -> str:
    versions, _ = asc.get_all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})
    found = next((v for v in versions if v["attributes"]["versionString"] == CONFIG["version"]), None)
    attributes = {"copyright": CONFIG["copyright"], "releaseType": CONFIG["releaseType"]}
    if found is None and versions:
        # A new app comes with an empty first version; give it our number.
        found = versions[0]
        attributes["versionString"] = CONFIG["version"]
    if found:
        patch(asc, "appStoreVersions", found["id"], "version", attributes)
        return found["id"]
    created = asc.create("appStoreVersions", attributes | {"platform": "IOS", "versionString": CONFIG["version"]},
                         {"app": ref("apps", app_id)}, "version")
    if created is None:
        sys.exit(1)
    return created["id"]


def version_texts_and_screenshots(asc: Client, version_id: str) -> None:
    print("Description, keywords, promotional text, support link")
    have, _ = asc.get_all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    by_locale = {item["attributes"]["locale"]: item for item in have}
    for locale_dir in sorted(METADATA.iterdir()):
        locale = locale_dir.name
        attributes = {"description": text(locale, "description"), "keywords": text(locale, "keywords"),
                      "promotionalText": text(locale, "promotional_text"), "supportUrl": text(locale, "support_url")}
        attributes = {k: v for k, v in attributes.items() if v}
        if locale not in by_locale:
            attributes["locale"] = locale
        row = upsert(asc, "appStoreVersionLocalizations", by_locale.get(locale), attributes,
                     ("appStoreVersion", ref("appStoreVersions", version_id)), f"version text {locale}")
        if row:
            by_locale[locale] = row

    if not SHOTS.is_dir():
        print(f"No screenshots folder {SHOTS}, skipping screenshots")
        return
    display = CONFIG["screenshotDisplayType"]
    for locale, row in sorted(by_locale.items()):
        prefix = CONFIG["screenshotLanguages"].get(locale)
        files = sorted(SHOTS.glob(f"{prefix}-[0-9]*.png")) if prefix else []
        if not files:
            print(f"  {locale}: no screenshots")
            continue
        sets, _ = asc.get_all(f"/v1/appStoreVersionLocalizations/{row['id']}/appScreenshotSets")
        shot_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display), None)
        if shot_set is None:
            shot_set = asc.create("appScreenshotSets", {"screenshotDisplayType": display},
                                  {"appStoreVersionLocalization": ref("appStoreVersionLocalizations", row["id"])},
                                  f"screenshot set {locale}")
            if shot_set is None:
                continue
        current, _ = asc.get_all(f"/v1/appScreenshotSets/{shot_set['id']}/appScreenshots")
        wanted = [md5(f.read_bytes()) for f in files]
        if [s["attributes"].get("sourceFileChecksum") for s in current] == wanted:
            print(f"  {locale}: {len(files)} screenshots already up to date")
            continue
        for old in current:
            response = asc.request("DELETE", f"/v1/appScreenshots/{old['id']}")
            if response.status_code != 204:
                problems.append(f"delete screenshot {locale}: {describe(response)}")
        uploaded = sum(upload(asc, "appScreenshots", ("appScreenshotSet", ref("appScreenshotSets", shot_set["id"])),
                              f, f"screenshot {locale} {f.name}") for f in files)
        print(f"  {locale}: uploaded {uploaded} of {len(files)}")


def review_details(asc: Client, version_id: str) -> None:
    print("Notes for App Review")
    notes = (HERE / "review-notes.md").read_text().split("---", 1)[-1].strip()
    attributes: dict = {"notes": notes, "demoAccountRequired": False}
    contact = {"contactFirstName": "REVIEW_FIRST_NAME", "contactLastName": "REVIEW_LAST_NAME",
               "contactPhone": "REVIEW_PHONE", "contactEmail": "REVIEW_EMAIL"}
    for field, env in contact.items():
        if os.environ.get(env, "").strip():
            attributes[field] = os.environ[env].strip()
    if "contactEmail" not in attributes:
        print("  Contact for App Review not set (secrets REVIEW_FIRST_NAME, REVIEW_LAST_NAME, REVIEW_PHONE, REVIEW_EMAIL)")
    existing = get_one(asc, f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")
    upsert(asc, "appStoreReviewDetails", existing, attributes,
           ("appStoreVersion", ref("appStoreVersions", version_id)), "review details")


def subscription_review_screenshots(asc: Client, app_id: str) -> None:
    print("Paywall screenshot for subscription review")
    path = SHOTS / CONFIG["reviewScreenshot"]
    if not path.exists():
        print(f"  {path} not found, skipping")
        return
    groups, _ = asc.get_all(f"/v1/apps/{app_id}/subscriptionGroups")
    for group in groups:
        subscriptions, _ = asc.get_all(f"/v1/subscriptionGroups/{group['id']}/subscriptions")
        for subscription in subscriptions:
            name = subscription["attributes"]["productId"]
            if get_one(asc, f"/v1/subscriptions/{subscription['id']}/appStoreReviewScreenshot"):
                print(f"  {name}: already has one")
                continue
            if upload(asc, "subscriptionAppStoreReviewScreenshots", ("subscription", ref("subscriptions", subscription["id"])),
                      path, f"review screenshot {name}"):
                print(f"  {name}: uploaded")


def free_price(asc: Client, app_id: str) -> None:
    print("Price")
    response = asc.request("GET", f"/v1/apps/{app_id}/appPriceSchedule", params={"include": "manualPrices"})
    if response.status_code == 200 and response.json().get("included"):
        print("  already set")
        return
    points, _ = asc.get_all(f"/v1/apps/{app_id}/appPricePoints", {"filter[territory]": "USA"})
    free = next((p for p in points if float(p["attributes"]["customerPrice"]) == 0), None)
    if free is None:
        problems.append("price: no free price point for USA")
        return
    payload = {
        "data": {"type": "appPriceSchedules", "relationships": {
            "app": {"data": ref("apps", app_id)},
            "baseTerritory": {"data": ref("territories", "USA")},
            "manualPrices": {"data": [ref("appPrices", "${free}")]},
        }},
        "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": ref("appPricePoints", free["id"])}}}],
    }
    response = asc.request("POST", "/v1/appPriceSchedules", data=json.dumps(payload))
    if response.status_code == 201:
        print("  set to free")
    else:
        problems.append(f"price: {describe(response)}")


def worldwide(asc: Client, app_id: str) -> None:
    print("Availability")
    if get_one(asc, f"/v1/apps/{app_id}/appAvailabilityV2"):
        print("  already set")
        return
    territories, _ = asc.get_all("/v1/territories")
    ids = [t["id"] for t in territories]
    payload = {
        "data": {"type": "appAvailabilities", "attributes": {"availableInNewTerritories": True}, "relationships": {
            "app": {"data": ref("apps", app_id)},
            "territoryAvailabilities": {"data": [ref("territoryAvailabilities", f"${{{t}}}") for t in ids]},
        }},
        "included": [{"type": "territoryAvailabilities", "id": f"${{{t}}}", "attributes": {"available": True},
                      "relationships": {"territory": {"data": ref("territories", t)}}} for t in ids],
    }
    response = asc.request("POST", "/v2/appAvailabilities", data=json.dumps(payload))
    if response.status_code == 201:
        print(f"  all {len(ids)} countries and regions")
    else:
        problems.append(f"availability: {describe(response)}")


def main() -> None:
    asc = Client()
    apps, _ = asc.get_all("/v1/apps", {"filter[bundleId]": CONFIG["bundleId"]})
    if not apps:
        print(f"No app with bundle id {CONFIG['bundleId']} in App Store Connect.")
        sys.exit(1)
    app_id = apps[0]["id"]
    print(f"App {apps[0]['attributes']['name']} ({app_id})")

    patch(asc, "apps", app_id, "content rights", {"contentRightsDeclaration": CONFIG["contentRights"]})
    app_info_and_texts(asc, app_id)
    version_id = version(asc, app_id)
    version_texts_and_screenshots(asc, version_id)
    review_details(asc, version_id)
    subscription_review_screenshots(asc, app_id)
    free_price(asc, app_id)
    worldwide(asc, app_id)

    print("\nStill by hand in App Store Connect: App Privacy (answers in appstore/app-privacy.md).")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"- {problem}")
        sys.exit(1)
    print("Done.")


if __name__ == "__main__":
    main()
