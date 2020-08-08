# Topolys Measures

This is a repo for OpenStudio Measures that use the [Topolys gem](https://github.com/automaticmagic/topolys). Linking Topolys  with OpenStudio has the potential to provide improved surface intersection and matching, checks if spaces are fully enclosed, or other new functionality. The first measure will be CheckModel and will check the OpenStudio Model's topology.

# Development

To install gem dependencies:

    bundle update
    
To copy dependencies to measure resources:

    bundle exec rake update_library_files

To run all tests: 

    bundle exec rake
    
To run specific tests: 

    openstudio lib/measures/check_model/tests/check_model_test.rb
