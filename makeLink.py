import json
import os
import random
import string
import psycopg2
from urllib.parse import urlparse

url = urlparse(os.environ["DATABASE_URL"])


def create_shorturl(event, context):
    conn = psycopg2.connect(
        database=url.path[1:],
        user=url.username,
        password=url.password,
        host=url.hostname,
        port=url.port,
        sslmode="require",
    )
    data = json.loads(event["body"])
    original_url = data["url"]
    if "slug" in data:
        shorturl = data["slug"]
    else:
        # Generate a random 6-character alphanumeric string
        chars = string.ascii_lowercase + string.ascii_uppercase + string.digits
        shorturl = "".join(random.choices(chars, k=6))
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO urls (shorturl, url, hits, devices, locations) VALUES (%s, %s, %s, %s, %s) ON CONFLICT (shorturl) DO UPDATE set url = %s ",
        (shorturl, original_url, 0, "{}", "{}", original_url),
    )
    conn.commit()
    cur.close()
    conn.close()
    # Return the short URL and its stats
    stats = {"shorturl": shorturl, "hits": 0, "devices": {}, "locations": {}}
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(stats),
    }
