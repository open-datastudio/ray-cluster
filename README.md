# Ray cluster

Run ray (https://github.com/ray-project/ray) cluster on [staroid](https://staroid.com).

[![Run](https://staroid.com/api/run/button.svg)](https://staroid.com/api/run)


## Getting started

### Connecting ray cluster from [open-datastudio/jupyter](https://github.com/open-datastudio/jupyter)


### Connecting ray cluster from any remote environment


## Development

Run locally using skaffold on minikube

```
skaffold dev -f .staroid/skaffold.yaml -p minikube --port-forward
```

Then in your python environment,

```
$ pip install ray
$ python
Python 3.7.4 (default, Jul  9 2019, 18:13:23) 
Type "help", "copyright", "credits" or "license" for more information.
>>> import ray
>>> ray.init()
```
