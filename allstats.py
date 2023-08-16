import psycopg2
import json
from urllib.parse import urlparse
import os

dbURL = urlparse(os.environ["DATABASE_URL"])


def all_links(event, context):
    # Determine the page number and size from the event
    try:
        page = int(event.get("queryStringParameters", {}).get("page", 1))
        size = int(event.get("queryStringParameters", {}).get("size", 10))
        search = event.get("queryStringParameters", {}).get("search", "")
        offset = (page - 1) * size
    except:
        page = 1
        size = 10
        offset = 0
        search = ""
    if search != "":
        offset = 0
        size = 999999999

    # Connect to the PostgreSQL database
    conn = psycopg2.connect(
        database=dbURL.path[1:],
        user=dbURL.username,
        password=dbURL.password,
        host=dbURL.hostname,
        port=dbURL.port,
        sslmode="require",
    )
    cur = conn.cursor()

    # Retrieve the short_code, original_url, number of hits, and last_click time for all URLs

    cur.execute(
        """
        SELECT urls.shorturl, urls.url, 
               COUNT(url_stats.user_ip) as hits, 
               MAX(url_stats.request_time) as last_click 
        FROM urls 
        LEFT JOIN url_stats ON urls.shorturl = url_stats.url
        WHERE urls.shorturl LIKE %s
        GROUP BY urls.shorturl, urls.url
        LIMIT %s OFFSET %s;
    """,
        ("%" + search + "%", size, offset),
    )
    results = cur.fetchall()

    # Count total number of records for pagination data
    cur.execute(
        """
        SELECT COUNT(*) FROM urls;
    """
    )
    total = cur.fetchone()[0]

    cur.close()
    conn.close()

    # Format the results into a list of dictionaries
    data = []
    for row in results:
        link_data = {
            "short_code": row[0],
            "url": row[1],
            "hits": row[2] if row[2] is not None else 0,
            "last_click": str(row[3]) if row[3] is not None else None,
        }
        data.append(link_data)

    # Return the data as a JSON response
    return {
        "statusCode": 200,
        "body": json.dumps(
            {
                "data": data,
                "pagination": {
                    "current": page,
                    "total": (total // size) + (total % size > 0),
                },
            }
        ),
        "headers": {"Content-Type": "application/json"},
    }
