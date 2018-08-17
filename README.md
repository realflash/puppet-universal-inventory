
# Universal Inventory

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with universal_inventory](#setup)
    * [What universal_inventory affects](#what-universal_inventory-affects)
    * [Setup requirements](#setup-requirements)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Limitations - OS compatibility, etc.](#limitations)
5. [Development - Guide for contributing to the module](#development)
6. [Unintentional Contributors](#unintentional-contributors)

## Description

This module queries the local package database for a list of installed package
 names and versions, and returns the data as a piece of JSON (with the ultimte
 intention that you can then query that fact centrally and do something with it).
 Whilst there are plenty of modules in Puppet Forge that are dedicated to inventoring
 specific OSs, this is the only one (to my knowledge) that queries all the major
 OSs whatever they are. 
 
### OS Support

I've listed the modern current versions of the OS that I have test this module on,
but the technologoies used to query the local package database are old so you
will almost certainly get it to work on older and newer versions of these OSs.
Please submit success and failure reports as GutHub issues so that I can extend 
the list.

Here's the method of querying packages for each OS:

  * APT-based Linux distributions: dpkg-query
  * RPM-based Linux distributions: rpm
  * Windows: wmic
  * OS X: system_profiler
  
So if that command exists on your OS, it will probabably work. HOWEVER: the module 
is designed to choose its query method based on the puppet fact _operatingsystem_.
 If your _operatingsystem_ string doesn't match one of the ones recognised by the
 module, it will error out. To get your OS added, open an issue on GitHub.

## Setup

### What universal_inventory affects **OPTIONAL**

Adds a fact called 'inventory'. No changes are made to the target node.

### Setup Requirements **OPTIONAL**

None.

## Usage

Just install and the fact will become available.

## Development

Contributions welcome at GitHub.

## Unintentional Contributors

Thank you to those whose code I borrowed:

 * Cody Herriges <cody@puppetlabs.com> who wrote ody/pkginventory
 * jhaals/app_inventory

