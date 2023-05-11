if __name__ == "__main__":
    from . import ADO
    from trinoor.config import Config
    import argparse
    import os
    from argparse import (
        ArgumentParser,
        _ArgumentGroup as ArgumentGroup,
        Namespace,
        RawDescriptionHelpFormatter,
    )
    import textwrap
    from pathlib import Path

    parser: ArgumentParser = argparse.ArgumentParser(
        prog=__package__, formatter_class=RawDescriptionHelpFormatter
    )
    action_group: ArgumentGroup = parser.add_argument_group("action")
    # Treat the first positional argument as the file path
    action_group.add_argument(
        "-L",
        "--list-pull-requests",
        dest="action",
        action="store_const",
        const="list",
        help="list the available pull requests",
    )
    parser.add_argument(
        "-c",
        "--config",
        default="",
        type=Path,
        help="The path to the config file",
    )
    parser.add_argument(
        "-P",
        "--pat",
        default=os.environ.get("ADO_PAT"),
        type=str,
        help="The personal access token to use",
    )
    parser.add_argument(
        "-o",
        "--organization",
        default="trinoor",
        type=str,
        help="The organization to use",
    )
    parser.add_argument(
        "-p",
        "--project",
        default=None,
        type=str,
        help="The project to use",
    )

    parser.epilog = textwrap.dedent(
        """
        This provides a command line interface to Azure DevOps via trinoor.ado
    """
    )
    args: Namespace = parser.parse_args()

    ado: ADO = ADO(
        config=args.config,
        pat=args.pat,
        organization=args.organization,
        project=args.project,
    )
    ado._connection.authenticate()

    if args.action == "list":
        for pr in ado.get_all_pull_requests(project_name=args.project):
            print(pr.as_dict())
