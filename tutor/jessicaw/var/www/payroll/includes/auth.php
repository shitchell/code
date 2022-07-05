<?php

class Auth {

	// we store a reference to the database so that we can access it
	var $db = null;
	function __construct($db) {
		$this->db = $db;
	}

	// get information about logged in user if available, false if not logged in
	function user_id() {
		return @$_SESSION['user_id'];
	}
	function eid() {
		return @$_SESSION['eid'];
	}
	function name() {
		return @$_SESSION['name'];
	}

	// basic authentication functions
	function logout() {
		session_destroy();
	}

	
	
    //filters any fishy input
    function sqli_filter($string) {
		$filtered_string = $string;
		$filtered_string = str_replace("admin'","",$filtered_string);
		$filtered_string = str_replace("ADMIN'","",$filtered_string);
		$filtered_string = str_replace("or","",$filtered_string);
		$filtered_string = str_replace("collate","",$filtered_string);
		$filtered_string = str_replace("drop","",$filtered_string);
		$filtered_string = str_replace("and","",$filtered_string);
		$filtered_string = str_replace("OR","",$filtered_string);
		$filtered_string = str_replace("COLLATE","",$filtered_string);
		$filtered_string = str_replace("DROP","",$filtered_string);
		$filtered_string = str_replace("AND","",$filtered_string);
		$filtered_string = str_replace("union","",$filtered_string);
		$filtered_string = str_replace("UNION","",$filtered_string);
		$filtered_string = str_replace("/*","",$filtered_string);
		$filtered_string = str_replace("*/","",$filtered_string);
		$filtered_string = str_replace("//","",$filtered_string);
		$filtered_string = str_replace(";","",$filtered_string);
		$filtered_string = str_replace("||","",$filtered_string);
		$filtered_string = str_replace("--","",$filtered_string);
		$filtered_string = str_replace("#","",$filtered_string);
		
		return $filtered_string;
	}
	
	
	function login($username, $password) {
		$escaped_username = $this->sqli_filter($username);
		// get the user's salt
		$sql = "SELECT * FROM users WHERE eid='$escaped_username'";
		$result = $this->db->query($sql);
		$user = $result->next();
		// make sure the user exists
		if (!$user) {
			notify('User does not exist', -1);
			return false;
		}
		// verify the password hash
		$salt = $user['salt'];
		$hash = md5($salt.$password);
		$sql = "SELECT * FROM users WHERE eid='$escaped_username' AND password='$hash'";
		$userdata = $this->db->query($sql)->next();
		if ($userdata) {
			// awesome, we're logged in
			$_SESSION['user_id'] = $userdata['user_id'];
			$_SESSION['eid'] = $userdata['eid'];
			$_SESSION['name'] = $userdata['name'];
		} else {
			notify('Invalid password', -1);
			return false;
		}
	}
	function register($name, $username, $password1, $password2) {
		$escaped_name = $this->db->escape($name);
		$escaped_username = $this->sqli_filter($username);
		// make sure the user doesn't exist
		$sql = "SELECT user_id FROM users WHERE eid='$escaped_username'";
		$result = $this->db->query($sql);
		if ($result->next()) {
			notify('User exists!', -1);
			return false;
		}
		// make sure the passwords match
		if ($password1 != $password2) {
			notify('Passwords do not match', -1);
			return false;
		}
		// OK good to go! Generate a salt and insert the user
		$salt = mt_rand(10000,99999);
		$hash = md5($salt.$password1);
		$sql = "INSERT INTO users (name, eid, password, salt) VALUES ".
			"('$escaped_name', '$escaped_username', '$hash', '$salt')";
		$this->db->query($sql);
		// redirect to homepage
		notify('Account '.$username.' registered. Please log in');
	}
}
