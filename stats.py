import psycopg2
import json
from urllib.parse import urlparse
import os


dbURL = urlparse(os.environ["DATABASE_URL"])


def short_stats(event, context):
    # Retrieve the short_code from the path parameters of the API Gateway event
    shorturl = event["pathParameters"]["shorturl"]

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

    # Retrieve hits, countries, user agents, and referrers for the given short_code
    cur.execute(
        """
        SELECT COUNT(*) as hits, 
               user_country, 
               user_agent, 
               user_referrer 
        FROM url_stats 
        WHERE url LIKE %s 
        GROUP BY user_country, user_agent, user_referrer;
    """,
        ("%" + shorturl,),
    )
    results = cur.fetchall()

    # Retrieve the original URL for the given short_code
    cur.execute(
        """
        SELECT url FROM urls WHERE shorturl = %s;
    """,
        (shorturl,),
    )
    original_url = cur.fetchone()[0]

    cur.close()
    conn.close()

    # Format the results into a dictionary
    countries = {}
    user_agents = {}
    referrers = {}
    hits = 0
    for row in results:
        hits += row[0]
        if row[1] is not None:
            if row[1] in countries:
                countries[row[1]] += row[0]
            else:
                countries[row[1]] = row[0]
        if row[2] is not None:
            if row[2] in user_agents:
                user_agents[row[2]] += row[0]
            else:
                user_agents[row[2]] = row[0]
        if row[3] is not None:
            if row[3] in referrers:
                referrers[row[3]] += row[0]
            else:
                referrers[row[3]] = row[0]
    data = {
        "shorturl": shorturl,
        "hits": hits,
        "countries": countries,
        "user_agents": user_agents,
        "referrers": referrers,
        "original_url": original_url,
    }

    # Return the data as a JSON response
    return {
        "statusCode": 200,
        "body": json.dumps(data),
        "headers": {"Content-Type": "application/json"},
    }
