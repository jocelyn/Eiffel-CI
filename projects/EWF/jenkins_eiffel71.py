#!/usr/local/bin/python
# Small python-script run all tests using ec (the Eiffel compiler) 
# we assume that ec outputs everything in english!
# For the command line options look at
# http://docs.eiffel.com/book/eiffelstudio/eiffelstudio-command-line-options
# we use often the -batch open.
#
# TODO: Fix problems when compiling takes too long and/or there
#       are ec process lingering around from a previous failed build

import os;
import sys;
import tempfile;
import shutil;
import re;
import subprocess;
from time import sleep;

def last_build_had_failure():
	return os.path.exists (".last_run_CI_tests_failed")

def reset_last_run_CI_tests_failed():
	fn = ".last_run_CI_tests_failed"
	if os.path.exists (fn):
		os.remove(fn)

def set_last_run_CI_tests_failed(m):
	fn = ".last_run_CI_tests_failed"
	f = open(".last_run_CI_tests_failed", 'w')
	f.write(m)
	f.close()

def report_failure(msg, a_code=2):
	print msg
	set_last_run_CI_tests_failed(msg)
	sys.exit(a_code)

# Override system command.
# run command. if not successful, complain and exit with error
def eval_cmd(cmd):
	#  print cmd
	res = subprocess.call (cmd, shell=True)
	if res != 0:
		report_failure ("Failed running: %s (returncode=%s)" % (cmd, res), 2)
	return res

def eval_cmd_output(cmd, ignore_error=False, display_as_it_execute=False):
	#  print cmd
	p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	if p:
		if display_as_it_execute:
			stdout = []
			while True:
				line = p.stdout.readline()
				stdout.append(line)
				print "%s" % (line),
				if line == '' and p.poll() != None:
					break
			o = ''.join(stdout)
		else:
			o = p.communicate()[0]

		return [p.returncode, o]
	else:
		if not ignore_error:
			report_failure ("Failed running: %s" % (cmd), 2)

def rm_dir(d):
	if os.path.isdir(d):
		shutil.rmtree(d)

def ecb_command():
	return os.path.join (os.environ['ISE_EIFFEL'],"studio", "spec", os.environ['ISE_PLATFORM'], "bin", "ecb")

def compile_all_command():
	return os.path.join (os.environ['ISE_EIFFEL'],"tools", "spec", os.environ['ISE_PLATFORM'], "bin", "compile_all")

def runTestForProject(where, args):
	if not os.path.isdir(where):
		report_failure ("Directory %s does not exist" % (where), 2)

	os.chdir(where)
	# First we have to remove old compilation

	location = args["location"]
	clobber = args["clobber"]
	keep_all = args["keep_all"]

	if not clobber:
		clobber = last_build_had_failure()

#	clobber = (len(sys.argv) >= 2 and sys.argv[1] == "-clobber") or (last_build_had_failure())
	reset_last_run_CI_tests_failed()
	if clobber:
		print "## Cleaning previous tests"
		rm_dir("EIFGENs")

	# compile the restbucks
	#print "# Compiling restbucks example"
	#cmd = "%s -config %s -target restbucks -batch -c_compile -project_path . " % (ecb_command(), os.path.join ("examples", "restbucksCRUD", "restbucks-safe.ecf"))
	#res = eval_cmd(cmd)
	#sleep(1)
		
	print "# check compile_all tests"
	compdir = os.path.join("comp")
	logsdir = os.path.join("logs")
	
	if not os.path.exists(compdir):
		os.makedirs (compdir)
	if not os.path.exists(logsdir):
		os.makedirs (logsdir)

	(res, res_output) = eval_cmd_output("%s -version" %(compile_all_command()), True)
	print res_output

	cmd = "%s -ecb -melt -l %s -logdir %s -compdir %s -ignore %s " % (compile_all_command(), location,  logsdir, compdir, os.path.join (location, "tests", "compile_all.ini"))
	if keep_all:
		cmd = "%s -keep passed" % (cmd) # forget about failed one .. we'll try again next time
	if clobber:
		cmd = "%s -clean" % (cmd)
	print "command: %s" % (cmd)
	(res, res_output) = eval_cmd_output(cmd, False, True)
	if res != 0:
		report_failure("compile_all failed", 2)

	print "# Analyze check_compilations results"
	lines = re.split ("\n", res_output)
	regexp = "^(\S+)\s+(\S+)\s+from\s+([^\s]+)\s+\(([^\)]+)\):\s*(\S+)$"
	p = re.compile (regexp);
	failures = [];
	non_failures = [];
	for line in lines:
		print line
		p_res = p.search(line.strip(), 0)
		if p_res:
			# name, target, ecf, result
			if p_res.group(5) == "failed":
				failures.append ({"name": p_res.group(2), "target": p_res.group(3), "ecf": p_res.group(4), "result": p_res.group(5)})
			else:
				non_failures.append ({"name": p_res.group(2), "target": p_res.group(3), "ecf": p_res.group(4), "result": p_res.group(5)})
	for non_fails in non_failures:
		print "[%s] %s : %s @ %s" % (non_fails["result"], non_fails["name"], non_fails["ecf"], non_fails["target"])
	for fails in failures:
		print "[FAILURE] %s : %s @ %s" % (fails["name"], fails["ecf"], fails["target"])
	sleep(1)
	if len(failures) > 0:
		report_failure ("Failure(s) occurred", 2)

	print "# End..."

if __name__ == '__main__':
	args = {}
	args["location"] = os.getcwd()
	args["clobber"] = False
	args["keep_all"] = True

	i = 0;
	while i < len (sys.argv):
		a = sys.argv[i]
		if a == "-clobber":
			args["clobber"] = True
		if a == "-keep":
			args["keep_all"] = True
		if a == "-forget":
			args["keep_all"] = False
		if a == "-location":
			i = i + 1
			args["location"] = sys.argv[i]
		i = i + 1
	runTestForProject(os.getcwd(), args)

