# Home Assistant Configuration

[Home Assistant Core](https://home-assistant.io/) running on [my Kubernetes cluster](https://github.com/billimek/k8s-gitops).  This configuration is read and persisted within Home Assistant.

## Screenshots

Default View
![default view](https://i.imgur.com/bn19oeC.png "Default View")

Camera View
![camera view](https://i.imgur.com/1wTt9ja.png "Camera View")

Z-Wave View
![z-wave view](https://i.imgur.com/ZUTuq4S.png "Z-Wave View")

Climate View
![climate view](https://i.imgur.com/ccK8AcO.png "Climate View")

Security View
![security view](https://i.imgur.com/p0OpPCs.png "Security View")

## Points of interest

* Home-Assistant is running within a kubernetes cluster running the the [home-assistant helm chart](https://github.com/k8s-at-home/charts/blob/master/charts/home-assistant)
* Automations are mostly performed via [node-red](https://nodered.org/) with the node-red configuration hosted in [this repo](https://github.com/billimek/node-red-config)
* In addition to use git to control the configuration, an [embeded](https://github.com/billimek/k8s-gitops/blob/master/default/home-assistant/home-assistant.yaml#L67-L82) instance of the [VSCode server](https://github.com/cdr/code-server) using the [home-assistant config helper extension](https://marketplace.visualstudio.com/items?itemName=keesschollaart.vscode-home-assistant) is leveraged to make live changes to the configuration files