"""Send Kinledger 1.0 to App Review: attach the newest processed build, add the subscriptions, submit.

Runs from .github/workflows/appstore-submit.yml. The version is released by hand after approval
(releaseType MANUAL in listing.json), so approval alone does not put the app on sale.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from create_subscriptions import Client, describe, problems, ref  # noqa: E402
from upload_listing import CONFIG, patch  # noqa: E402


def main() -> None:
    asc = Client()
    apps, _ = asc.get_all("/v1/apps", {"filter[bundleId]": CONFIG["bundleId"]})
    app_id = apps[0]["id"]

    versions, _ = asc.get_all(f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})
    version = next(v for v in versions if v["attributes"]["versionString"] == CONFIG["version"])
    state = version["attributes"].get("appVersionState") or version["attributes"].get("appStoreState")
    print(f"Version {CONFIG['version']}: {state}")

    builds, _ = asc.get_all("/v1/builds", {
        "filter[app]": app_id, "filter[preReleaseVersion.version]": CONFIG["version"],
        "filter[processingState]": "VALID", "sort": "-uploadedDate",
    })
    if not builds:
        print("No processed build yet; run the TestFlight workflow first.")
        sys.exit(1)
    build = builds[0]
    print(f"Build {build['attributes']['version']}")
    response = asc.request("PATCH", f"/v1/appStoreVersions/{version['id']}/relationships/build",
                           data=json.dumps({"data": ref("builds", build["id"])}))
    if response.status_code != 204:
        problems.append(f"attach build: {describe(response)}")

    print("Subscriptions")
    groups, _ = asc.get_all(f"/v1/apps/{app_id}/subscriptionGroups")
    for group in groups:
        subscriptions, _ = asc.get_all(f"/v1/subscriptionGroups/{group['id']}/subscriptions")
        for subscription in subscriptions:
            name, sub_state = subscription["attributes"]["productId"], subscription["attributes"]["state"]
            if sub_state == "READY_TO_SUBMIT":
                if asc.create("subscriptionSubmissions", {}, {"subscription": ref("subscriptions", subscription["id"])},
                              f"submit {name}"):
                    print(f"  {name}: added to the submission")
            else:
                print(f"  {name}: {sub_state}")

    print("App Review")
    open_ones, _ = asc.get_all("/v1/reviewSubmissions", {"filter[app]": app_id, "filter[platform]": "IOS",
                                                          "filter[state]": "READY_FOR_REVIEW"})
    submission = open_ones[0] if open_ones else asc.create(
        "reviewSubmissions", {"platform": "IOS"}, {"app": ref("apps", app_id)}, "review submission")
    if submission is None:
        report_and_exit()
    items, _ = asc.get_all(f"/v1/reviewSubmissions/{submission['id']}/items")
    if not items:
        asc.create("reviewSubmissionItems", {}, {
            "reviewSubmission": ref("reviewSubmissions", submission["id"]),
            "appStoreVersion": ref("appStoreVersions", version["id"]),
        }, "add version to submission")
    if not problems and patch(asc, "reviewSubmissions", submission["id"], "submit", {"submitted": True}):
        print("  sent: Waiting for Review")
    report_and_exit()


def report_and_exit() -> None:
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"- {problem}")
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
