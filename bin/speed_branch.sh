#! /bin/bash -e
# -----------------------------------------------------------------------------
# CppAD: C++ Algorithmic Differentiation: Copyright (C) 2003-18 Bradley M. Bell
#
# CppAD is distributed under multiple licenses. This distribution is under
# the terms of the
#                     Eclipse Public License Version 1.0.
#
# A copy of this license is included in the COPYING file of this distribution.
# Please visit http://www.coin-or.org/CppAD/ for information on other licenses.
# -----------------------------------------------------------------------------
possible_tests='
	all
	det_lu
	det_minor
	mat_mul ode
	poly
	sparse_hessian
	sparse_jacobian
'
possible_options='
	atomic
	boolsparsity
	colpack
	memory
	onetape
	optimize
	revsparsity
	subgraph
'
program="bin/speed_branch.sh"
if [ "$0" != "$program" ]
then
	echo "$program: must be executed from its parent directory"
	exit 1
fi
if [ "$3" == '' ]
then
tests=`echo $possible_tests | sed -e 's|\n||' -e 's|\t| |'`
options=`echo $possible_options | sed -e 's|\n||' -e 's|\t| |'`
cat << EOF
usage:
$program branch_one branch_two test_name [option_1] [option_2] ...

possible tests are:
$tests

possible options are:
$options
EOF
	exit 1
fi
#
branch_one="$1"
shift
branch_two="$1"
shift
test_name="$1"
if ! echo "$possible_tests" | grep "$test_name" > /dev/null
then
	echo "speed_branch.sh: $test_name is not a valid test name"
	exit 1
fi
shift
option_list="$test_name"
for option in $*
do
	if ! echo $possible_options | grep "$option" > /dev/null
	then
		echo "speed_branch.sh: $option is not a valid option"
		exit 1
	fi
	option_list="${option_list}_$option"
done
if [ "$test_name" == 'all' ]
then
	test_name='speed'
fi
# ----------------------------------------------------------------------------
# bash function that echos and executes a command
echo_eval() {
	echo $*
	eval $*
}
# -----------------------------------------------------------------------------
if [ ! -d '.git' ]
then
	echo "$program: only implemented for git repository"
	exit 1
fi
# -----------------------------------------------------------------------------
# copy this file to a separate name so can restore it when done
cp bin/speed_branch.sh speed_branch.copy.$$
git checkout bin/speed_branch.sh
# ----------------------------------------------------------------------------
build_dir='build/speed/cppad'
if [ ! -e $build_dir ]
then
	echo_eval mkdir -p $build_dir
fi
# -----------------------------------------------------------------------------
# get sizes in master speed/main.cpp
git show master:speed/main.cpp > speed_branch.main.$$
cat << EOF > speed_branch.sed.$$
/^\\tfor(size_t i = 0; i < n_size; i++)\$/! b skip
: loop
N
/\\n\\t}\$/! b loop
s/^\\tfor(size_t i = 0; i < n_size; i++)\\n\\t{/\\t/
s/\\n\\t}\$//
p
: skip
EOF
sed speed_branch.main.$$ -n -f speed_branch.sed.$$ > speed_branch.size.$$
#
# sed script to mark size location (must work if size_t not present)
cat << EOF > speed_branch.sed.$$
/^\\tfor([a-z_]* *i = 0; i < n_size; i++) *\$/! b skip
: loop
N
/\\n\\t}\$/! b loop
s|{|{\\n\\t// BEGIN_SIZES\\n\\t|
s|\\n\\t}\$|\\n\\t// END_SIZES&|
: skip
EOF
rm speed_branch.main.$$
# -----------------------------------------------------------------------------
for branch in $branch_one $branch_two
do
	# for stable branches, remove stable/ from output file name
	out_file=`echo $branch.$option_list.out | sed -e 's|stable/||'`
	log_file=`echo $branch.log | sed -e 's|stable/||'`
	#
	if [ -e "$build_dir/$out_file" ]
	then
		echo "Using existing $build_dir/$out_file"
	else
		# use --quiet to supress detached HEAD message
		echo_eval git checkout --quiet $branch
		#
		# changes sizes in speed/main.cpp to be same as in master branch
		sed -i speed/main.cpp -f speed_branch.sed.$$
		sed  speed/main.cpp  -n -e '1,/BEGIN_SIZES/p' > speed_branch.main.$$
		cat  speed_branch.size.$$                    >> speed_branch.main.$$
		sed  speed/main.cpp  -n -e '/END_SIZES/,$p'  >> speed_branch.main.$$
		mv speed_branch.main.$$ speed/main.cpp
		#
		# versions of CppAD before 20170625 did not have --debug_none option
		echo "bin/run_cmake.sh --debug_none >& $build_dir/$log_file"
		if ! bin/run_cmake.sh --debug_none >& $build_dir/$log_file
		then
			echo "bin/run_cmake.sh >& $build_dir/$log_file"
			bin/run_cmake.sh >& $build_dir/$log_file
		fi
		#
		echo_eval cd $build_dir
		#
		echo "make check_speed_cppad >> $build_dir/$log_file"
		make check_speed_cppad >> $log_file
		#
		echo "./speed_cppad $test_name 123 $* > $build_dir/$out_file"
		./speed_cppad $test_name 123 $* > $out_file
		#
		cd ../../..
		#
		# restore speed/main.cpp to state in repo
		git checkout speed/main.cpp
	fi
done
rm speed_branch.sed.$$
rm speed_branch.size.$$
mv speed_branch.copy.$$ bin/speed_branch.sh
#
# compare the results
echo "	one=$branch_one , two=$branch_two"
out_file_one=`echo $branch_one.$option_list.out | sed -e 's|stable/||'`
out_file_two=`echo $branch_two.$option_list.out | sed -e 's|stable/||'`
bin/speed_diff.sh $build_dir/$out_file_one $build_dir/$out_file_two
# ----------------------------------------------------------------------------
echo "$0: OK"
exit 0
