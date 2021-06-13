# inspectiontools

## 使用方法
1. 节点的k8s信息和主机信息需要在同一个路径下，目录结构如下
```bash
> tree
.
├── 10.129.142.80
│   ├── Dokcer_Info.json
│   └── Node_Info.json
├── 10.129.142.80.yaml
├── 10.129.142.81
│   ├── Dokcer_Info.json
│   └── Node_Info.json
├── 10.129.142.81.yaml
├── 10.129.142.82
│   ├── Dokcer_Info.json
│   └── Node_Info.json
├── 10.129.142.82.yaml
```
例如：
```bash
> ll
total 584
drwxr-xr-x  2 root root   4096 Jun 13 23:15 10.129.142.80
-rw-r--r--  1 1001 1001   7560 Mar 30 12:44 10.129.142.80.yaml
drwxr-xr-x  2 root root   4096 Jun 13 23:15 10.129.142.81
-rw-r--r--  1 1001 1001   7134 Mar 30 12:44 10.129.142.81.yaml
drwxr-xr-x  2 root root   4096 Jun 13 23:15 10.129.142.82
-rw-r--r--  1 1001 1001   8023 Mar 30 12:44 10.129.142.82.yaml

> ll 10.129.142.80
total 24
-rw-r--r-- 1 root root 11528 Jun 13 23:15 Dokcer_Info.json
-rw-r--r-- 1 root root  5413 Mar 30 12:42 Node_Info.json
```

2. 将该脚本放到这个路径下
```bash
> wget https://raw.githubusercontent.com/zerchin/inspectiontools/main/generate.sh
> ll
total 580
drwxr-xr-x 2 root root   4096 Jun 13 23:15 10.129.142.80
-rw-r--r-- 1 1001 1001   7560 Mar 30 12:44 10.129.142.80.yaml
drwxr-xr-x 2 root root   4096 Jun 13 23:15 10.129.142.81
-rw-r--r-- 1 1001 1001   7134 Mar 30 12:44 10.129.142.81.yaml
drwxr-xr-x 2 root root   4096 Jun 13 23:15 10.129.142.82
-rw-r--r-- 1 1001 1001   8023 Mar 30 12:44 10.129.142.82.yaml
-rw-r--r-- 1 root root  18056 Jun 13 23:15 generate.sh
```

3. 执行该脚本即可，会在当前目录下生成`Inspection_report.md`巡检报告
```bash
> bash generate.sh
```
