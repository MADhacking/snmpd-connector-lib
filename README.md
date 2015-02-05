snmpd-connector-lib
===================

The SNMP daemon provided in the net-analyzer/net-snmp package supports a variety of extension mechanisms including "pass-through scripts" which allow simple Bash scripts to be used to extend the functionality of the agent. Unfortunately, writing such a script is a non-trivial exercise not least because the extension agent is required to assist the SNMP daemon by providing access to the MIB structure. This knowledge of the MIB structure is essential to facilitate GETNEXT requests which enable "walking" the resulting tree.

The dev-libs/snmpd-connector-lib package provides an SNMPD agent/connector library for the Bash shell scripting language designed to assist with the development of new SNMPD agents/connectors, especially those providing access to tabular data, by providing an extremely simple API as well as other useful features including abstraction of the MIB structure. 

More information may be found at:

http://www.mad-hacking.net/software/linux/agnostic/snmpd-connector-lib/index.xml
