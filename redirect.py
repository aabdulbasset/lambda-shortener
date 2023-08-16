import json
import os
import random
import string
import time
import psycopg2
from urllib.parse import urlparse
import requests
from datetime import datetime
import threading

# Connect to the PostgreSQL database
dbURL = urlparse(os.environ["DATABASE_URL"])
conn = psycopg2.connect(
    database=dbURL.path[1:],
    user=dbURL.username,
    password=dbURL.password,
    host=dbURL.hostname,
    port=dbURL.port,
    sslmode="require",
)
cur = conn.cursor()


def lambda_handler(event, context):
    shorturl = event["pathParameters"]["shorturl"]

    # Look up URL in database

    cur.execute("SELECT url FROM urls WHERE shorturl = %s", (shorturl,))
    result = cur.fetchone()
    # Redirect user to URL if found, otherwise return 404
    if result:
        url = result[0]
        user_agent = map_user_agent(event["headers"].get("User-Agent"))
        user_ip = event["requestContext"]["identity"]["sourceIp"]
        user_country = get_user_country(user_ip)
        user_referrer = event["headers"].get("Referer")
        save_stats(shorturl, user_agent, user_ip, user_country, user_referrer)
        conn.commit()
        return {"statusCode": 301, "headers": {"Location": url}}

    else:
        return {
            "statusCode": 404,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"error": "Not found"}),
        }


def get_user_country(ip):
    response = requests.get(f"http://ip-api.com/json/{ip}?fields=countryCode")
    if response.status_code == 200:
        return response.json()["countryCode"]
    else:
        return "Unknown"


def save_stats(id, user_agent, user_ip, user_country, user_referrer):
    cur.execute(
        "INSERT INTO url_stats (url, user_agent, user_ip, user_country, user_referrer, request_time) VALUES (%s, %s, %s, %s, %s, %s)",
        (id, user_agent, user_ip, user_country, user_referrer, datetime.now()),
    )


def map_user_agent(user_agent):
    ua = user_agent.lower()

    if "android" in ua:
        return "android"
    elif "iphone" in ua or "ipad" in ua:
        return "ios"
    elif "windows" in ua:
        return "windows"
    elif "mac" in ua:
        return "mac"
    elif "bot" in ua:
        return "bot"
    else:
        return "other"
