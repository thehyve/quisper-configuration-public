# quisper-configuration
This repository contains configuration files for the Quisper Server Platform.

## QSP
The Quisper Server Platform consists of an nginx server that proxies requests from quisper clients to webservice providers. While doing so, it connects to the 3scale API management system to check credentials, adhere to limits and store statistics.

## nginx
An nginx server with lua support is required for the configuration scripts to work properly. The current puppet configuration uses the OpenResty module to install nginx and the appropriate nginx modules.

## Configuration
The configuration consists of a central nginx configuration file (named qsp.conf). This file uses a set of lua scripts to do most of the work:

* **qsp.lua** contains the main logic for looking up parameters for each webservice. In essence it looks up the parameters for the required service from services.lua. It passes the parameters to the nginx server, and if authentication is needed, it will request authentication checking from the 3scale backend. 
* **services.lua** contains the definitions for the different services. 
* **bodyfilter.lua** contains logic to filter the body of the webservice response. This is mainly used to update any URLs that are returned by the webservice to the new URL using the proxy. Its behavior can be configured in using the webservice_substitution entries in services.lua.
* **3scale.lua** contains functions as provided by 3scale concerning the communication with the 3scale backend.
* **utils.lua** contains some custom made utility functions

## Get started
Replace all instances of <YOUR_PROVIDER_KEY> with your 3scale API key and add services to qsp.conf and services.lua as described in the documentation.
