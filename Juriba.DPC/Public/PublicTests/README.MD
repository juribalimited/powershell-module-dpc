# 
Run against the test environment

Install Pester using:  Import-Module Pester -PassThru
Run tests: Invoke Pester 
Mock - use this where ossible so we cna minimise test data cleanup
Test Environment - we do not need to test against multiple environments

## Goals of the tests
* The goal of the scripts is 
* The goal of the Pester tests are to verify that the modules are working.
### In scope
* Testing that the module itself works from a behavioural perspective

### Out of scope:
* Testing that the endpoint is returning correct data - this is tested by unit and integrationn tests
* Testing all permutations of error messages from 

We need to think about
How do we make these useful