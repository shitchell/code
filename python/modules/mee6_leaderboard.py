#!/usr/bin/env python3

LEADERBOARD_URL = "https://mee6.xyz/api/plugins/levels/leaderboard/"

class LeaderboardInvalidException(Exception): pass

def get_leaderboard(leaderboard_id: str,
                    detailed: bool = False,
                    as_dataframe: bool = True):
    """
    Return the data for a given leaderboard id. If detailed is set to false,
    only the user information is shared. If detailed is true, all of the
    available information (e.g. xp range, xp message interval, etc) is given.
    If dataframe is true, the user information is returned as a pandas
    dataframe.
    """
    import requests
    res = requests.get(LEADERBOARD_URL + leaderboard_id)
    if not res.ok:
        raise LeaderboardInvalidException()
    res = res.json()
    if as_dataframe:
        import pandas as pd
        res["players"] = pd.DataFrame(res["players"])
    if detailed:
        return res
    return res["players"]

def level_points(level: int) -> int:
    """
    Returns the number of points required to reach the given level
    """
    # determined with https://www.dcode.fr/function-equation-finder
    return int(((5*level**3)/3 + (45*level**2)/2 + 455*level/6))

if __name__ == "__main__":
    import argparse
    import pandas as pd

    parser = argparse.ArgumentParser(description="Fetch a Mee6 leaderboard.")
    #parser = argparse.ArgumentParser(description="Process some integers.")
    parser.add_argument("leaderboard",
                        help="the mee6 leaderboard id (e.g. 621181761870757898)")
    parser.add_argument("-q", "--quiet", action="store_true",
                        help="don't print any output")
    parser.add_argument("-n", "--next-level", dest="next", action="store_true",
                        help="show the xp required to reach the next level")
    parser.add_argument("-t", "--top", type=int, default=100,
                        help="show only the top N results")
    parser.add_argument("--db", dest="db_filepath",
                        help="path to a sqlite database to store results")
    parser.add_argument("--db-table", dest="db_table", default="leaderboard",
                        help="name of the table to use in the database")
    args = parser.parse_args()

    def _print(*a, **k):
        if not args.quiet:
            print(*a, **k)

    users = get_leaderboard(args.leaderboard)
    
    # a couple column modifications
    users["user"] = users["username"] + "#" + users["discriminator"]
    users.rename({"message_count": "messages"}, axis=1, inplace=True)
    users.drop(["detailed_xp", "guild_id", "id", "avatar", "discriminator"], axis=1, inplace=True)

    # prepare a dataframe to print
    df = users[:args.top].copy()
    if args.next:
        # add a column to show how much xp to the next level
        df["xp_up"] = (df["level"] + 1).apply(level_points) - df["xp"]
        df = df[["username", "messages", "xp", "xp_up", "level"]]
    else:
        df = df[["username", "messages", "xp", "level"]]
    _print(df)

    # save the data if db option is selected
    if args.db_filepath:
        import time
        import sqlite3

        conn = sqlite3.connect(args.db_filepath)

        # add a timestamp
        users["timestamp"] = int(time.time())

        ## ensure the leaderboard table exists
        def scrub(name: str) -> str:
            """remove everything except alphanumeric chars & underscores"""
            import re
            return re.sub("[^A-z_]", "", name)
        # sanitize name and columns
        name = scrub(args.db_table)
        cols = [scrub(col) for col in users.columns]
        # generate create statement
        stmt = f"CREATE TABLE IF NOT EXISTS {name} ({', '.join(cols)})"
        # create table
        conn.execute(stmt)
        conn.commit()

        # write leaderboard data to db
        users.to_sql(
            "leaderboard",
            con=conn,
            if_exists="append",
            index=False
        )
