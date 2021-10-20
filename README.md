# HelloID-Conn-Prov-Source-magister



## Table of contents

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Prerequisites](#Prerequisites)
  + [Remarks](#Remarks)
- [Setup the connector](Setup-The-Connector)
- [Getting help](Getting-help)

## Introduction
The HelloID-Conn-Prov-Source-magister is used to retrieve employee and students from Magster.

## Getting started

### Prerequisites
 - URL to the webservice. Example: https://tools4ever.swp.nl:8800
 - username
 - password
 - layoutname
 - magister application manager stand by for importing the layout

### Actions
| Retrieve te data in csv format.


### Connection settings
The following settings are required to connect to the API.

| Setting     | Description |
| ------------ | ----------- |
| username     | The username   |
| Password   | The password  |
| BaseUrl    |    The URL to the Magister environment. Example: https://tools4ever.swp.nl:8800
| layout | Name of the list in Decibel to export




### Remarks
 - Execute on-premises
 - The magsiter application manager must create an layout named "tools4ever-leerlingen-actief"
 - The magister application manager must import the contents off the layout "tools4ever-leerlingen-actief" into decibel
 - The username must be authorized for the layout "tools4ever-leerlingen-actief"
 - documentation can be found at https://<tenant>.swp.nl:8800/doc?


## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012557600-Configure-a-custom-PowerShell-source-system) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID Docs

The official HelloID documentation can be found at: https://docs.helloid.com/
