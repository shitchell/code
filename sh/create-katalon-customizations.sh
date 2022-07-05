#!/bin/bash
#
# Author: shaun
# Date:   2022/01/06
#
# Takes an input file with a list of customisation IDs as an argument and:
#   1. generates Test Cases/{submodule} folders
#   2. generates customization folders within the appropriate submodule
#   3. generates a Test Case script within each customization folder

# create skeleton test case
read -r -d '' SKELETON_SCRIPTS << ENDSS
import static com.kms.katalon.core.checkpoint.CheckpointFactory.findCheckpoint
import static com.kms.katalon.core.testcase.TestCaseFactory.findTestCase
import static com.kms.katalon.core.testdata.TestDataFactory.findTestData
import static com.kms.katalon.core.testobject.ObjectRepository.findTestObject
import static com.kms.katalon.core.testobject.ObjectRepository.findWindowsObject
import com.kms.katalon.core.checkpoint.Checkpoint as Checkpoint
import com.kms.katalon.core.cucumber.keyword.CucumberBuiltinKeywords as CucumberKW
import com.kms.katalon.core.mobile.keyword.MobileBuiltInKeywords as Mobile
import com.kms.katalon.core.model.FailureHandling as FailureHandling
import com.kms.katalon.core.testcase.TestCase as TestCase
import com.kms.katalon.core.testdata.TestData as TestData
import com.kms.katalon.core.testng.keyword.TestNGBuiltinKeywords as TestNGKW
import com.kms.katalon.core.testobject.TestObject as TestObject
import com.kms.katalon.core.webservice.keyword.WSBuiltInKeywords as WS
import com.kms.katalon.core.webui.keyword.WebUiBuiltInKeywords as WebUI
import com.kms.katalon.core.windows.keyword.WindowsBuiltinKeywords as Windows
import internal.GlobalVariable as GlobalVariable
import org.openqa.selenium.Keys as Keys
ENDSS

# create skeleton for Scripts folder entry
read -r -d '' SKELETON_TESTCASES << ENDSTC
<?xml version="1.0" encoding="UTF-8"?>
<TestCaseEntity>
   <description></description>
   <name>{name}</name>
   <tag></tag>
   <comment></comment>
   <testCaseGuid>{uuid}</testCaseGuid>
</TestCaseEntity>
ENDSTC

cd-project-root() {
  while [ -z "$(echo *.prj)" ] || [ ! -d "Test Cases" ]; do
    # exit if we reach the root directory
    if [ "$(pwd)" = "/" ]; then
      return 1
    else
      cd ..
    fi
  done
}

get-testcase-submodule() {
  echo "$1" | cut -d '-' -f 3
}

testcase-create() {
  testcase="$1"
  submodule="$(get-testcase-submodule $testcase)"
  scripts_dir="Scripts/$submodule/$testcase/$(echo $testcase | tr '-' '_')"
  testcases_dir="Test Cases/$submodule/$testcase"

  # create test customization folders in Scripts/ and Test Cases/
  mkdir -p "$scripts_dir" || echo "-> couldn't create $scripts_dir"
  mkdir -p "$testcases_dir" || echo "-> couldn't create $testcases_dir"

  # create groovy script in Scripts/ folder
  epoch="$(date +%s%N | grep --color=never -oP '.{13}')"
  uuid="$(uuidgen | tr '[A-Z]' '[a-z]')"
  scripts_filename="Script$epoch.groovy"
  scripts_path="$scripts_dir/$scripts_filename"
  echo "$SKELETON_SCRIPTS" > "$scripts_path"
  [ $? -eq 0 ] && echo "-> $scripts_path"

  # create .tc file in Test Cases/ folder
  tc_filename="$(echo $testcase.tc | tr '-' '_')"
  tc_path="$testcases_dir/$tc_filename"
  echo "$SKELETON_TESTCASES" | sed "s/{uuid}/$uuid/" | sed "s/{name}/${tc_filename::-3}/" > "$tc_path"
  [ $? -eq 0 ] && echo "-> $tc_path"
}

infile="$1"
if [ -z "$infile" ]; then
  echo 'please supply an input file with a list of customization ids' >&2
  exit 1
fi

while read customization; do
  customization="$(echo $customization | tr -d '\r\n')"
  echo "-- $customization --"
  testcase-create "$customization"
done < "$infile"
