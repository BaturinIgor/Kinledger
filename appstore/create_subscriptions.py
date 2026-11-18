"""Create the Kinledger Pro subscriptions in App Store Connect from appstore/subscriptions.json.

Runs from .github/workflows/appstore-subscriptions.yml. Safe to run again: anything that already
exists (group, plans, names, prices, trials) is left as it is and only what is missing is added.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_PRIVATE_KEY (an App Store Connect API key with the
App Manager role).
"""
import json
import os
import sys
import time
from pathlib import Path

import jwt
import requests

API = "https://api.appstoreconnect.apple.com"
CONFIG = json.loads((Path(__file__).parent / "subscriptions.json").read_text())
problems: list[str] = []


class Client:
    def __init__(self) -> None:
        self.key_id = os.environ["ASC_KEY_ID"].strip()
        self.issuer = os.environ["ASC_ISSUER_ID"].strip()
        self.private_key = os.environ["ASC_PRIVATE_KEY"].strip()
        self.session = requests.Session()
        self.token_made = 0.0
        self.token = ""

    def headers(self) -> dict:
        if time.time() - self.token_made > 600:
            now = int(time.time())
            self.token = jwt.encode(
                {"iss": self.issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"},
                self.private_key,
                algorithm="ES256",
                headers={"kid": self.key_id, "typ": "JWT"},
            )
            self.token_made = time.time()
        return {"Authorization": f"Bearer {self.token}", "Content-Type": "application/json"}

    def request(self, method: str, path: str, **kwargs) -> requests.Response:
        url = path if path.startswith("http") else API + path
        for attempt in range(5):
            response = self.session.request(method, url, headers=self.headers(), timeout=60, **kwargs)
            if response.status_code == 429 or response.status_code >= 500:
                time.sleep(2 ** attempt)
                continue
            return response
        return response

    def get_all(self, path: str, params: dict | None = None) -> tuple[list, list]:
        """Every page of a list. Returns (data, included)."""
        data, included = [], []
        url, query = path, dict(params or {})
        query.setdefault("limit", 200)
        while url:
            response = self.request("GET", url, params=query)
            if response.status_code != 200:
                fail(f"GET {url}", response)
            body = response.json()
            data += body.get("data", [])
            included += body.get("included", [])
            url, query = body.get("links", {}).get("next"), None
        return data, included

    def create(self, kind: str, attributes: dict, relationships: dict, what: str) -> dict | None:
        payload = {"data": {"type": kind, "attributes": attributes, "relationships": {
            name: {"data": value} for name, value in relationships.items()
        }}}
        response = self.request("POST", f"/v1/{kind}", data=json.dumps(payload))
        if response.status_code == 201:
            return response.json()["data"]
        problems.append(f"{what}: {describe(response)}")
        print(f"  ! {what}: {describe(response)}")
        return None


def describe(response: requests.Response) -> str:
    try:
        errors = response.json().get("errors", [])
        return "; ".join(f"{e.get('title')} - {e.get('detail')}" for e in errors) or response.text[:300]
    except ValueError:
        return f"HTTP {response.status_code} {response.text[:300]}"


def fail(what: str, response: requests.Response) -> None:
    print(f"Stopped at {what}: HTTP {response.status_code} {describe(response)}")
    if response.status_code == 401:
        print("The API key was refused. Check ASC_KEY_ID, ASC_ISSUER_ID and that ASC_PRIVATE_KEY holds the whole .p8 file.")
        explain_key()
    if response.status_code == 403:
        print("The API key has no rights for this. Give it the App Manager (or Admin) role.")
    sys.exit(1)


def explain_key() -> None:
    """Facts about the key that help find a typo, without printing anything secret."""
    import re
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer = os.environ.get("ASC_ISSUER_ID", "").strip()
    pem = os.environ.get("ASC_PRIVATE_KEY", "").strip()
    print(f"- key id: {len(key_id)} characters, looks right: {bool(re.fullmatch(r'[A-Z0-9]{10}', key_id))}")
    print(f"- issuer id: {len(issuer)} characters, looks like a UUID: "
          f"{bool(re.fullmatch(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', issuer))}")
    print(f"- private key: starts with BEGIN PRIVATE KEY: {pem.startswith('-----BEGIN PRIVATE KEY-----')}, "
          f"ends with END PRIVATE KEY: {pem.endswith('-----END PRIVATE KEY-----')}, lines: {len(pem.splitlines())}")


def ref(kind: str, ident: str) -> dict:
    return {"type": kind, "id": ident}


def main() -> None:
    asc = Client()

    apps, _ = asc.get_all("/v1/apps", {"filter[bundleId]": CONFIG["bundleId"]})
    if not apps:
        print(f"No app with bundle id {CONFIG['bundleId']} in App Store Connect.")
        sys.exit(1)
    app_id = apps[0]["id"]
    print(f"App {apps[0]['attributes']['name']} ({app_id})")

    # 1. The group and its name in every language.
    groups, _ = asc.get_all(f"/v1/apps/{app_id}/subscriptionGroups")
    group = next((g for g in groups if g["attributes"]["referenceName"] == CONFIG["group"]), None)
    if group is None:
        group = asc.create("subscriptionGroups", {"referenceName": CONFIG["group"]},
                           {"app": ref("apps", app_id)}, "group")
        if group is None:
            sys.exit(1)
        print(f"Created group {CONFIG['group']}")
    else:
        print(f"Group {CONFIG['group']} already exists")
    group_id = group["id"]

    have, _ = asc.get_all(f"/v1/subscriptionGroups/{group_id}/subscriptionGroupLocalizations")
    have_locales = {item["attributes"]["locale"] for item in have}
    for locale, text in CONFIG["locales"].items():
        if locale not in have_locales:
            if asc.create("subscriptionGroupLocalizations", {"name": text["group"], "locale": locale},
                          {"subscriptionGroup": ref("subscriptionGroups", group_id)}, f"group name {locale}"):
                print(f"  group name {locale}")

    # 2. The plans.
    existing, _ = asc.get_all(f"/v1/subscriptionGroups/{group_id}/subscriptions")
    by_product = {s["attributes"]["productId"]: s for s in existing}
    territories, _ = asc.get_all("/v1/territories")
    territory_ids = [t["id"] for t in territories]

    for plan in CONFIG["plans"]:
        key = "monthly" if plan["period"] == "ONE_MONTH" else "yearly"
        sub = by_product.get(plan["productId"])
        if sub is None:
            sub = asc.create("subscriptions", {
                "name": plan["referenceName"],
                "productId": plan["productId"],
                "subscriptionPeriod": plan["period"],
                "familySharable": False,
                "reviewNote": CONFIG["reviewNote"],
                "groupLevel": plan["level"],
            }, {"group": ref("subscriptionGroups", group_id)}, plan["productId"])
            if sub is None:
                continue
            print(f"Created {plan['productId']}")
        else:
            print(f"{plan['productId']} already exists")
        sub_id = sub["id"]

        # Names and descriptions.
        have, _ = asc.get_all(f"/v1/subscriptions/{sub_id}/subscriptionLocalizations")
        have_locales = {item["attributes"]["locale"] for item in have}
        added = 0
        for locale, text in CONFIG["locales"].items():
            if locale not in have_locales:
                if asc.create("subscriptionLocalizations",
                              {"name": text[key], "description": text["description"], "locale": locale},
                              {"subscription": ref("subscriptions", sub_id)}, f"{key} name {locale}"):
                    added += 1
        print(f"  names: {added} added, {len(have_locales)} already there")

        # Price: the US price, and Apple's matching price in every other country.
        points, _ = asc.get_all(f"/v1/subscriptions/{sub_id}/pricePoints",
                                {"filter[territory]": "USA", "include": "territory"})
        us_point = next((p for p in points if float(p["attributes"]["customerPrice"]) == float(plan["usd"])), None)
        if us_point is None:
            problems.append(f"{plan['productId']}: no US price point {plan['usd']}")
            continue
        equal, _ = asc.get_all(f"/v1/subscriptionPricePoints/{us_point['id']}/equalizations",
                               {"include": "territory"})
        point_for = {"USA": us_point["id"]}
        for p in equal:
            territory = p.get("relationships", {}).get("territory", {}).get("data")
            if territory:
                point_for[territory["id"]] = p["id"]

        prices, _ = asc.get_all(f"/v1/subscriptions/{sub_id}/prices", {"include": "territory"})
        priced = {p["relationships"]["territory"]["data"]["id"] for p in prices
                  if p.get("relationships", {}).get("territory", {}).get("data")}
        added = 0
        for territory, point in point_for.items():
            if territory in priced:
                continue
            if asc.create("subscriptionPrices", {"startDate": None, "preserveCurrentPrice": False}, {
                "subscription": ref("subscriptions", sub_id),
                "subscriptionPricePoint": ref("subscriptionPricePoints", point),
                "territory": ref("territories", territory),
            }, f"{key} price {territory}"):
                added += 1
        print(f"  prices: {added} added, {len(priced)} already there, {len(point_for)} countries")

        # Sold everywhere the app is, including countries Apple adds later.
        availability = asc.request("GET", f"/v1/subscriptions/{sub_id}/subscriptionAvailability")
        if availability.status_code != 200 or not availability.json().get("data"):
            if asc.create("subscriptionAvailabilities", {"availableInNewTerritories": True}, {
                "subscription": ref("subscriptions", sub_id),
                "availableTerritories": [ref("territories", t) for t in territory_ids],
            }, f"{key} availability"):
                print("  availability: all countries")
        else:
            print("  availability already set")

        # One free week for new subscribers, in every country.
        offers, _ = asc.get_all(f"/v1/subscriptions/{sub_id}/introductoryOffers", {"include": "territory"})
        offered = {o["relationships"]["territory"]["data"]["id"] for o in offers
                   if o.get("relationships", {}).get("territory", {}).get("data")}
        added = 0
        for territory in point_for:
            if territory in offered:
                continue
            if asc.create("subscriptionIntroductoryOffers", {
                "duration": CONFIG["trial"], "offerMode": "FREE_TRIAL", "numberOfPeriods": 1,
            }, {
                "subscription": ref("subscriptions", sub_id),
                "territory": ref("territories", territory),
            }, f"{key} free week {territory}"):
                added += 1
        print(f"  free week: {added} added, {len(offered)} already there")

    if problems:
        print(f"\n{len(problems)} things did not go through:")
        for problem in problems[:60]:
            print(f"- {problem}")
        sys.exit(1)
    print("\nDone. Still by hand in App Store Connect: the review screenshot of the paywall for each plan.")


if __name__ == "__main__":
    main()
