"""Open the uploaded build to outside testers through a public TestFlight link (KAN-112).

Runs from .github/workflows/testflight.yml after the upload. Waits until Apple has processed the build,
then fills the test information in 18 languages, creates the public group with a tester limit,
adds the build and sends it to beta review. Safe to run again. Settings and texts: appstore/beta.json.

Needs the App Store Connect key (ASC_*), BUILD_NUMBER, and for outside testing a contact:
REVIEW_FIRST_NAME, REVIEW_LAST_NAME, REVIEW_PHONE, REVIEW_EMAIL (FEEDBACK_EMAIL defaults to REVIEW_EMAIL).
"""
import json
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from create_subscriptions import Client, describe, problems, ref  # noqa: E402
from upload_listing import get_one, patch, upsert  # noqa: E402

HERE = Path(__file__).parent
BETA = json.loads((HERE / "beta.json").read_text())
LISTING = json.loads((HERE / "listing.json").read_text())


def env(name: str, fallback: str = "") -> str:
    return os.environ.get(name, "").strip() or fallback


def wait_for_build(asc: Client, app_id: str, number: str) -> dict:
    print(f"Waiting for build {number} to finish processing")
    for _ in range(90):
        builds, _ = asc.get_all("/v1/builds", {"filter[app]": app_id, "filter[version]": number})
        if builds:
            state = builds[0]["attributes"]["processingState"]
            if state == "VALID":
                print("  ready")
                return builds[0]
            if state in ("FAILED", "INVALID"):
                print(f"  Apple could not process the build: {state}")
                sys.exit(1)
        time.sleep(30)
    print("  still not processed after 45 minutes; run the workflow's beta step again later")
    sys.exit(1)


def main() -> None:
    asc = Client()
    apps, _ = asc.get_all("/v1/apps", {"filter[bundleId]": LISTING["bundleId"]})
    app_id = apps[0]["id"]
    build = wait_for_build(asc, app_id, env("BUILD_NUMBER"))
    build_id = build["id"]

    # The contact and feedback email may come from secrets or be typed in App Store Connect.
    detail = get_one(asc, f"/v1/apps/{app_id}/betaAppReviewDetail")
    typed = (detail or {}).get("attributes", {})
    contact_email = env("REVIEW_EMAIL", typed.get("contactEmail") or "")

    print("Test information in every language")
    have, _ = asc.get_all(f"/v1/apps/{app_id}/betaAppLocalizations")
    by_locale = {item["attributes"]["locale"]: item for item in have}
    typed_feedback = next((i["attributes"].get("feedbackEmail") for i in have if i["attributes"].get("feedbackEmail")), "")
    feedback = env("FEEDBACK_EMAIL", typed_feedback or contact_email)
    for locale, texts in BETA["texts"].items():
        attributes = {"description": texts["description"], "privacyPolicyUrl": BETA["privacyPolicyUrl"]}
        if feedback:
            attributes["feedbackEmail"] = feedback
        if locale not in by_locale:
            attributes["locale"] = locale
        upsert(asc, "betaAppLocalizations", by_locale.get(locale), attributes,
               ("app", ref("apps", app_id)), f"beta info {locale}")

    print("What to test, in every language")
    have, _ = asc.get_all(f"/v1/builds/{build_id}/betaBuildLocalizations")
    by_locale = {item["attributes"]["locale"]: item for item in have}
    for locale, texts in BETA["texts"].items():
        attributes = {"whatsNew": texts["whatsNew"]}
        if locale not in by_locale:
            attributes["locale"] = locale
        upsert(asc, "betaBuildLocalizations", by_locale.get(locale), attributes,
               ("build", ref("builds", build_id)), f"what to test {locale}")

    print("Contact for beta review")
    attributes = {"notes": BETA["reviewNotes"], "demoAccountRequired": False}
    for field, name in {"contactFirstName": "REVIEW_FIRST_NAME", "contactLastName": "REVIEW_LAST_NAME",
                        "contactPhone": "REVIEW_PHONE", "contactEmail": "REVIEW_EMAIL"}.items():
        if env(name):
            attributes[field] = env(name)
    if detail:
        patch(asc, "betaAppReviewDetails", detail["id"], "beta review contact", attributes)

    print(f"Public group, up to {BETA['testers']} testers")
    groups, _ = asc.get_all(f"/v1/apps/{app_id}/betaGroups")
    group = next((g for g in groups if g["attributes"]["name"] == BETA["group"]), None)
    link = {"publicLinkEnabled": True, "publicLinkLimitEnabled": True, "publicLinkLimit": BETA["testers"],
            "feedbackEnabled": True}
    if group is None:
        group = asc.create("betaGroups", {"name": BETA["group"]} | link, {"app": ref("apps", app_id)}, "beta group")
        if group is None:
            sys.exit(1)
    else:
        patch(asc, "betaGroups", group["id"], "beta group link", link)

    response = asc.request("POST", f"/v1/betaGroups/{group['id']}/relationships/builds",
                           data=json.dumps({"data": [ref("builds", build_id)]}))
    if response.status_code not in (200, 204):
        problems.append(f"add build to group: {describe(response)}")

    print("Beta review")
    if not contact_email:
        problems.append("beta review needs a contact: TestFlight → Test Information → Beta App Review Information")
    elif get_one(asc, f"/v1/builds/{build_id}/betaAppReviewSubmission"):
        print("  already sent")
    elif asc.create("betaAppReviewSubmissions", {}, {"build": ref("builds", build_id)}, "beta review"):
        print("  sent; Apple usually answers within a day")

    group = get_one(asc, f"/v1/betaGroups/{group['id']}") or group
    print(f"\nPublic TestFlight link: {group['attributes'].get('publicLink') or 'appears after beta review'}")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"- {problem}")
        sys.exit(1)


if __name__ == "__main__":
    main()
