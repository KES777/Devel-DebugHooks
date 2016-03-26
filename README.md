Perl debugger

How to run:

	perl -d:DebugHooks::Terminal script.pl

	## Debug remotely
	# FIX harcoded server:port at
	# Devel::DebugHooks::Server.pm:107
	# on remote
	perl -d:DebugHooks::Server script.pl
	# on local
	./dclient.pl 1.2.3.4 9000




Quick guide for commands:

	s - single step. Trace into
	n - single step. Trace over
	r - return from sub.
	go - run script until the end or next trap
	go N - run script to 'N' line
	q - quit debugger
	R - restart debugging. Works only while remotely debugging script runned under uwsgi

	f - list all files
	f regex - list all files that match regex
	f N - set 'N' file as current

	l . - list source at current step
	l - list next source page
	l $coderef - deparce subroutine
	l -N - list source for N frame
	l &N - deparse subroutine for N frame

	vars - show variables visible from current step
	vars N - show variables visible from N frame
	vars N $var - show value from $var variable at N frame

	t [$x|@x|%x] - trace and log into 'vars.log' access to given variable

	T - stack trace.
	T N - show only N last frames
	NOTICE: stacktrace will shows GOTO!!! frames also

	b - list all traps
	b . - set trap at current step
	b . condition - set conditional trap
	b [+|-][file:|M:]N - set trap at given file:line
		+ - enable trap
		- - disable trap
		file - absolute path to file
		M - number from 'f' command output
		N - line number at file
	save|load - Save/Load info about traps into ~/.dbginit file

	a expr - set action
	A expr - remove action
	w expr - set watch
	W expr - remove watch

	expr - evaluate 'expr' from user's script perspective
	e expr - evaluate 'expr' from user's script perspective and Data::Dump::pp results

	ge - run editor for current file
	ge file:N - run editor for given file


This module implement for shortcut invader operator `x::x;` this is same as  `$DB::single = 1;`
