/* --------------------------------------------------------------------------
CppAD: C++ Algorithmic Differentiation: Copyright (C) 2003-19 Bradley M. Bell

CppAD is distributed under the terms of the
             Eclipse Public License Version 2.0.

This Source Code may also be made available under the following
Secondary License when the conditions for such availability set forth
in the Eclipse Public License, Version 2.0 are satisfied:
      GNU General Public License, Version 2.0 or later.
---------------------------------------------------------------------------- */
/*
$begin json_cexp_op.cpp$$
$spell
    abs
    Json
$$

$section Json abs Operator: Example and Test$$

$head Source Code$$
$srcfile%example/json/cexp_op.cpp%0%// BEGIN C++%// END C++%1%$$

$end
*/
// BEGIN C++
# include <cppad/cppad.hpp>

bool cexp_op(void)
{   bool ok = true;
    using CppAD::vector;
    using CppAD::AD;
    double eps99 = 99.0 * std::numeric_limits<double>::epsilon();
    //
    // AD graph example
    // node_1 : p[0]
    // node_2 : x[0]
    // node_3 : c[0]
    // node_4 : cexp_le(p[0], x[0], p[0], x[0])
    // y[0]   = cexp_le(p[0], x[0], p[0], x[0])
    // use single quote to avoid having to escape double quote
    std::string graph =
        "{\n"
        "   'function_name'  : 'cexp_op example',\n"
        "   'op_define_vec'  : [ 1, [\n"
        "       { 'op_code':1, 'name':'cexp_le', 'n_arg':4 } ]\n"
        "   ],\n"
        "   'n_dynamic_ind'  : 1,\n"
        "   'n_independent'  : 1,\n"
        "   'constant_vec'   : 1, [ -0.1 ],\n" // c[0]
        "   'op_usage_vec'   : 1, [\n"
        "       [ 1, 1, 2, 1, 2 ]      ]\n" // cexp_le(p[0], x[0], p[0], x[0])
        "   ,\n"
        "   'dependent_vec' : 1, [4]\n"
        "}\n";
    // Convert the single quote to double quote
    for(size_t i = 0; i < graph.size(); ++i)
        if( graph[i] == '\'' ) graph[i] = '"';
    //
    // f(x, p) = cexp_le(p[0], x[0], p[0], x[0])
    CppAD::ADFun<double> f;
    f.from_json(graph);
    ok &= f.Domain() == 1;
    ok &= f.Range() == 1;
    ok &= f.size_dyn_ind() == 1;
    //
    // set independent variables and parameters
    vector<double> p(1), x(1);
    p[0] = 0.2;
    x[0] = 0.3;
    //
    // compute y = f(x, p)
    f.new_dynamic(p);
    vector<double> y = f.Forward(0, x);
    //
    // check result
    double check;
    if( p[0] <= x[0] )
        check= p[0];
    else
        check = x[0];
    //
    // Convert to Json graph and back again
    graph = f.to_json();
    f.from_json(graph);
    //
    // compute y = f(x, p)
    f.new_dynamic(p);
    y = f.Forward(0, x);
    //
    // check result
    ok &= CppAD::NearEqual(y[0], check, eps99, eps99);
    //
    return ok;
}
// END C++
