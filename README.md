# Ray cluster

This repository provides ability to run [Ray](https://ray.io) cluster on [Staroid](https://staroid.com).

The repository includes

 - Target project to deploy when launching ray using ray [Staroid node provider](https://github.com/ray-project/ray/tree/master/python/ray/autoscaler/staroid)

## Getting started

Install staroid python module

```
$ pip install staroid
```

[Get staroid access token](https://staroid.com/settings/accesstokens) and set `STAROID_ACCESS_TOKEN` env variable.

```
$ export STAROID_ACCESS_TOKEN="<Your access token>"
```

Get latest ray source code

```
$ git clone https://github.com/ray-project/ray
$ cd ray
```

Use Ray cluster launcher

```
# Create or update cluster
$ ray up python/ray/autoscaler/staroid/example-full.yaml

# Get a remote screenon the head node
$ ray attach python/ray/autoscaler/staroid/example-full.yaml
$ # Try running a Ray program with 'ray.init(address="auto")'.

# Tear down the cluster.
$ ray down ray/python/ray/autoscaler/staroid/example-full.yaml
```

See https://docs.ray.io/en/master/cluster/cloud.html#staroid for more details.
