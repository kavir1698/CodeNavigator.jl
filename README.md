Code Navigator
===============

NOTE: work in progress. There are bugs.

This package is a tool for analyzing and visualizing Julia code. It provides a way to scan Julia files in a directory, analyze function calls, and create a UML diagram to visualize the relationships between functions. This is a static call graph.

This is useful for understanding the structure and dependencies of your Julia codebase. It can help developers identify complex relationships between functions, detect potential issues, and improve code organization.

How to use it
--------------

To use Code Navigator, simply include the package in your Julia project and call the `scan_julia_files_in_directory` function, passing in the directory you want to analyze. You can also customize the analysis by specifying options such as excluding certain folders, including external functions, saving the results to a file, and creating a UML diagram.

Here's an example:

```julia
using CodeNavigator

functions = scan_julia_files_in_directory("/path/to/directory", exclude_folders=String[], include_external_functions=false, save_to_file=false, create_diagram=true)
```
