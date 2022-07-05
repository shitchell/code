import argparse
import flask
import os
import subprocess
import time

from _io import TextIOWrapper
from flask import request, jsonify
from pathlib import Path
from queue import Queue
from subprocess import Popen
from threading import Thread

app = flask.Flask(__name__)
app.config["DEBUG"] = True

parser = argparse.ArgumentParser(description="katalon server api")
parser.add_argument("-p", "--port", default=5000, type=int,
                    help="port to run the server on")
parser.add_argument("-b", "--host", default="localhost", type=str,
                    help="host to run the server on")
parser.add_argument("-c", "--katalonc", default="./katalonc", required=True, type=Path,
                    help="path to the katalonc executable")
parser.add_argument("-k", "--katalon-project", default=".", type=Path,
                    help="path to the katalon project")
parser.add_argument("-u", "--update-drivers", action="store_true", default=True,
                    help="automatically update drivers before launching a test suite")
parser.add_argument("--profile", default="DEV", type=str,
                    help="default execution profile")
parser.add_argument("--browser", default="Chrome (headless)",
                    help="default browser type")
parser.add_argument("--organization-id", default="",
                    help="organization id")
parser.add_argument("--kre-license", default="",
                    help="kre license (consider using the KRE_LICENSE environment variable)")
parser.add_argument("-d", "--log-directory", default="./logs", type=Path,
                     help="directory to store log files")
parser.add_argument("-v", "--verbose", action="count", default=1,
                    help="increase verbosity")
args = parser.parse_args()

def create_log_dir():
    # create the log directory if it doesn't exist
    if not args.log_directory.exists():
        args.log_directory.mkdir(parents=True)

LOGFILE = open(args.log_directory / (os.path.basename(__file__) + ".log"), "a")
def log(message: str, level: int = 1, stdout: bool = app.config["DEBUG"]) -> None:
    '''
    Logs a message with the given level. If stdout is set to false, the message
    will only be printed to the logfile. stdout defaults to True in debug mode,
    else it defaults to False.
    '''
    # create the log directory if it doesn't exist
    create_log_dir()
    if level <= args.verbose:
        timestamp: str = time.strftime("%Y-%m-%d %H:%M:%S")
        msg: str = f"[{timestamp}] {message}"
        if stdout:
            print(msg)
        LOGFILE.write(msg + "\n")
        LOGFILE.flush()

class MissingLicenseException(Exception): pass
class MissingOrganizationException(Exception): pass

class TestSuiteRun:
    CREATED: int = 0
    RUNNING: int = 1
    COMPLETED: int = 2

    def __init__(self, name: str, project: str, browser: str, profile: str,
                 kre_license: str, organization_id: str):
        self.name = name
        self.project = project
        self.browser = browser
        self.profile = profile
        self.kre_license = kre_license
        self.organization_id = organization_id
        self.proc: Popen | None = None
        self.status: int = TestSuiteRun.CREATED
        self.start_time: float = time.time()
        self.end_time: float = 0
        self._output: str = ""
        self._log_file: TextIOWrapper | None = None
        log(f"Created test suite run {self.name} with ident: {self.identifier}")

    @property
    def identifier(self):
        # generate a unique identifier for the run
        return time.strftime('%Y%m%d-%H%M%S', time.localtime(self.start_time)) + '-' + self.name

    @property
    def output(self) -> str:
        return self._output

    @property
    def duration(self) -> float:
        if self.end_time:
            return self.end_time - self.start_time
        return -1

    def start(self):
        test_args: list[str] = [
             '-v',
             '-noSplash',
             '-runMode=console',
            f'-projectPath={self.project}',
             '-retry=0',
            f'-testSuitePath=Test Suites/{self.name}',
            f'-reportFileName={self.identifier}',
            f'-executionProfile={self.profile}',
            f'-browserType={self.browser}',
            f'-apiKey={self.kre_license}'
        ]
        # if --update-drivers is set, add an option to update the drivers
        if args.update_drivers:
            test_args.extend(["--config", "-webui.autoUpdateDrivers=true"])
        # if an organization id is provided, add that
        if self.organization_id:
            test_args.append(f"-organizationId='{self.organization_id}'")
        print(f"Running test suite {self.name} with args: {test_args}")
        print(f"$ {args.katalonc} {' '.join(test_args)}")
        self.proc = subprocess.Popen(
            [args.katalonc, *test_args],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, # merge stdout and stderr
            universal_newlines=True
        )
        # start fetching the stdout
        stdout_thread: Thread = Thread(target=self._consume_stdout)
        stdout_thread.start()
        # update start status
        self.status = TestSuiteRun.RUNNING
        self.start_time = time.time()

    def wait(self):
        self.proc.wait()
        self.end_time = time.time()
        self.status = TestSuiteRun.COMPLETED

    def _setup_logging(self):
        create_log_dir()
        log_path: Path = args.log_directory / (self.identifier + ".log")
        self._log_file = open(log_path, "w")

    def _consume_stdout(self):
        for line in iter(self.proc.stdout.readline, ''):
            # TODO: don't log so much
            log(f"{self.identifier} -- {line.strip()}", stdout=False)
            self._log_file.write(line)
            self._output += line
        self._log_file.close()
        self.status = TestSuiteRun.COMPLETED
        self.end_time = time.time()

# function to get the kre license key from:
#  - the --kre-license command line argument
#  - a .kre.license file in the current directory
#  - the KRE_LICENSE environment variable
def get_kre_license() -> str:
    kre_license: str = args.kre_license
    if not kre_license and os.path.exists(".kre.license"):
        kre_license = Path('.kre.license').read_text()
    if not kre_license:
        kre_license = os.environ.get('KRE_LICENSE', '')
    return kre_license

# function to get the organization id from:
# - the --organization-id command line argument
# - a .organization.id file in the current directory
# - the KRE_ORGANIZATION_ID environment variable
def get_organization_id() -> str:
    organization_id: str = args.organization_id
    if not organization_id and os.path.exists(".organization.id"):
        organization_id = Path('.organization.id').read_text()
    if not organization_id:
        organization_id = os.environ.get('KRE_ORGANIZATION_ID', '')
    return organization_id

# watch the queue for new test suite runs and then run them
def monitor_queue():
    while True:
        try:
            # fetch the next test suite to run from the queue
            test_run: TestSuiteRun = TEST_RUN_QUEUE.get(block=True)
            # start the test suite
            test_run.start()
            # add the test suite to the running list
            TEST_RUNS[test_run.identifier] = test_run
            # wait for the test suite to finish
            test_run.wait()
        except Exception:
            pass

# function for returning consistent json responses
def build_payload(success: bool,
                  message: str | None = None,
                  payload: dict[object, object] | list[object] | None = None) -> str:
    '''
    Builds a json response with the given success, message, and payload
    '''
    response: dict[str, object] = {
        "success": success,
        "message": message,
        "payload": payload
    }
    return jsonify(response)

@app.route('/', methods=['GET'])
def home():
    return build_payload(True, "hello"), 200

def run_test_suite(test_suite: str,
                   kre_license: str,
                   profile: str = args.profile,
                   browser: str = args.browser) -> TestSuiteRun:
    '''
    Runs a test suite with the given name, profile, browser, and api key.
    '''
    # use default values if not provided
    if kre_license is None:
        kre_license = get_kre_license()
    if not profile:
        profile = args.profile
    if not browser:
        browser = args.browser

    # create a new test run
    test_run: TestSuiteRun = TestSuiteRun(
        test_suite,
        args.katalon_project,
        browser,
        profile,
        kre_license,
        args.organization_id
    )

    # add the test run to the list of test runs
    TEST_RUNS[test_run.identifier] = test_run

    # start the test run
    test_run.start()
    
    return test_run

@app.route('/api/v1/test-suite/run', methods=['POST', 'GET'])
def test_suite_run():
    '''
    Requires the name of a test suite to be passed with an optional
    execution profile, browser type, and api key.
    
    Request Parameters:
    - name: the name of the test suite to run
    - profile: the execution profile to use (defaults to DEV)
    - browser: the browser type to use (defaults to Chrome (headless))
    - kre_license: the license to use (defaults to the license loaded on the server)
    '''
    if request.method == 'POST':
        data = request.get_json()
    elif request.method == 'GET':
        data = request.args
    else:
        return build_payload(False, "invalid request method"), 400

    # check if the test suite name is provided
    if 'name' not in data:
        return build_payload(False, "test suite name not provided"), 400

    # run the test suite
    test_run: TestSuiteRun = run_test_suite(
        data['name'],
        data.get('kre_license'),
        data.get('profile'),
        data.get('browser')
    )

    return build_payload(True, payload={
        "id": test_run.identifier,
        "testSuite": test_run.name,
        "time": test_run.start_time,
        "profile": test_run.profile,
        "browser": test_run.browser
    }), 200

@app.route('/api/v1/test-suite/status', methods=['POST', 'GET'])
def test_suite_status():
    '''
    Check the status of a running test suite
    
    Request Parameters:
    - id: the identifier of the test suite returned by /api/v1/run/test-suite
    '''
    if request.method == 'POST':
        data = request.get_json()
    elif request.method == 'GET':
        data = request.args
    else:
        return build_payload(False, "invalid request method"), 400

    # get the test run with the given identifier
    test_run: TestSuiteRun = TEST_RUNS.get(data['id'], None)

    # if the test run does not exist, return an error
    if test_run is None:
        return build_payload(False, "test run not found"), 400

    # return the test run status
    duration: float
    if test_run.status == TestSuiteRun.RUNNING:
        duration = time.time() - test_run.start_time
    else:
        duration = test_run.duration
    return build_payload(True, payload={
        "status": test_run.status,
        "runTime": duration
    }), 200

@app.route('/api/v1/test-suite/output', methods=['POST', 'GET'])
def test_suite_output():
    '''
    Check the status of a running test suite
    
    Request Parameters:
    - id: the identifier of the test suite returned by /api/v1/run/test-suite
    '''
    if request.method == 'POST':
        data = request.get_json()
    elif request.method == 'GET':
        data = request.args
    else:
        return build_payload(False, "invalid request method"), 400

    # get the test run with the given identifier
    test_run: TestSuiteRun = TEST_RUNS.get(data['id'], None)

    # if the test run does not exist, return an error
    if test_run is None:
        return build_payload(False, "test run not found"), 400

    return test_run.output

# holds all active and completed test runs
TEST_RUNS: dict[str, TestSuiteRun] = {}
# holds all test runs that are waiting to be run
TEST_RUN_QUEUE: Queue[TestSuiteRun] = Queue()

# verify that a license is provided
if not get_kre_license():
    raise MissingLicenseException("No KRE license provided")

# start a thread to monitor the queue for new test runs
monitor_thread: Thread = Thread(target=monitor_queue)
monitor_thread.start()

# start the app
app.run()
