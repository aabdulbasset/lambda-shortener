import psycopg2
import os
import json
from urllib.parse import urlparse

# Replace these with the appropriate values for your database.
# Better to get these from Environment variables or Secrets Manager.
url = urlparse(os.environ["DATABASE_URL"])


def lambda_handler(event, context):
    # assuming the username and password are passed as event parameters
    data = json.loads(event["body"])
    username = data["username"]
    password = data["password"]

    conn = None
    try:
        # connect to the PostgreSQL server
        conn = psycopg2.connect(
            database=url.path[1:],
            user=url.username,
            password=url.password,
            host=url.hostname,
            port=url.port,
            sslmode="require",
        )
        # create a cursor
        cur = conn.cursor()

        # execute a statement
        cur.execute("SELECT password FROM users WHERE username = %s", (username,))

        # fetch the result
        result = cur.fetchone()

        # close the communication with the PostgreSQL
        cur.close()

        if result is None:
            return {"statusCode": 401, "body": json.dumps("Unauthorized")}

        if (
            password == result[0]
        ):  # Basic password check, replace with proper password hashing
            return {
                "statusCode": 200,
                "body": json.dumps(
                    {
                        "token": "jOIWdemEc010gnDswrUkz9voueHpgKBe3vr9JSHX",
                        "statusCode": 200,
                    }
                ),  # Replace with actual token
            }
        else:
            return {"statusCode": 401, "body": json.dumps("Unauthorized")}

    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
        return {"statusCode": 500, "body": "error"}
    finally:
        if conn is not None:
            conn.close()
