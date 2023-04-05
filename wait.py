import sys
import requests
import json
from collections import Counter
import time
import traceback
from datetime import datetime

before = datetime.timestamp(datetime.now())

def get_instances(api_prefix, app_uuid):
    response = requests.get(f"{api_prefix}/apps/{app_uuid}",
                            headers={"accept": "application/json"})
    result = json.loads(response.content)
    return [i["uuid"] for i in result["instances"]]


def get_images_by_instance(api_prefix, instance_uuid, correct_image):
    response = requests.get(f"{api_prefix}/instances/{instance_uuid}/containers",
                            headers={"accept": "application/json"})
    result = json.loads(response.content)
    spent = datetime.timestamp(datetime.now()) - before
    images = []
    for r in result:
        for c in r["containers"]:
            status = json.dumps(c['status'], indent=2)
            status = status.replace('\"','').replace('  ',' - ').replace('{',' === STATUS ===')[:-1]
            if c["image"] == correct_image:
                print(status, flush=True)
                if c.get("status").get("reason") is not None and "BackOff" in c["status"]["reason"] and spent > 60:
                    print(f"ERROR - Found any type of 'BackOff' on deploy. Check the logs on COPS interface.", flush=True)
                    sys.exit(1)
            if c["ready"]:
                images.append(c["image"])
    return images


def get_images_by_app(api_prefix, app_uuid, correct_image):
    result = []
    for instance_uuid in get_instances(api_prefix, app_uuid):
        result += get_images_by_instance(api_prefix, instance_uuid, correct_image)
    return result


def deploy_finished(api_prefix, app_id, correct_image):
    images = get_images_by_app(api_prefix, app_id, correct_image)
    counted = Counter(images)
    return len(counted) == 1 and counted.get(correct_image) is not None


def wait_deploy_finished(api_prefix, app_uuid, correct_image, timeout):
    while True:
        try:
            if deploy_finished(api_prefix, app_uuid, correct_image):
                return True
        except Exception as e:
            traceback.print_exc()
        time.sleep(5)
        spent = datetime.timestamp(datetime.now()) - before
        if spent > timeout:
            raise TimeoutError(
                f"Waited too much app {app_uuid} to update to {correct_image}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Needs three parameters: wait.py [image] [url] [timeout]")
        sys.exit(1)

    correct_image = sys.argv[1]
    cops_url = sys.argv[2]
    timeout = int(sys.argv[3])

    splitted = cops_url.split("/apps/")
    app_uuid = splitted[-1]
    api_prefix = splitted[0]

    print(f"Waiting deploy to finish", flush=True)
    print(f" - api_prefix: {api_prefix}", flush=True)
    print(f" - app_uuid: {app_uuid}", flush=True)
    print(f" - timeout: {timeout} seconds", flush=True)
    print(f" - correct_image: {correct_image}", flush=True)

    wait_deploy_finished(api_prefix, app_uuid, correct_image, timeout)
