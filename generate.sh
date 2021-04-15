#! /bin/bash


## 获取主机名
NODE_NAME=()
for i in * 
do
  if [[ -d $i ]]
  then
      NODE_NAME[${#NODE_NAME[*]}]=$i 
  fi
done

## 获取主机IP
NODE_IP=()
## 获取主机角色
NODE_ROLE=()
## 获取CPU使用百分比
NODE_CPU_PERCENT=()
## 获取内存使用百分比
NODE_MEM_PERCENT=()
## 获取SWAP分区使用百分比
NODE_SWAP_PRECENT=()
## 获取C磁盘使用百分比
NODE_DISK_PERCENT=()
## 获取操作系统版本
NODE_OS=()
## 内核版本
NODE_KERNEL=()
## Kubelet版本
NODE_KUBELET_VERSION=()
## Kube-proxy版本
NODE_KUBEPROXY_VERSION=()
## Docker版本
NODE_DOCKER_VERSION=()
## 获取节点资源预留/限制使用
NODE_CPU_REQUEST=()
NODE_CPU_LIMIT=()
NODE_MEM_REQUEST=()
NODE_MEM_LIMIT=()
NODE_CPU_REQUEST_PER=()
NODE_CPU_LIMIT_PER=()
NODE_MEM_REQUEST_PER=()
NODE_MEM__LIMIT_PER=()

# 计数
SWAP_COUNT=0
CPU_COUNT=0
MEM_COUNT=0
DISK_COUNT=0
CPU_REQUEST_COUNT=0
CPU_LIMIT_COUNT=0
MEM_REQUEST_COUNT=0
MEM_LIMIT_COUNT=0
for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
do
    ## 主机列表
    NODE_IP[${#NODE_IP[*]}]=`egrep InternalIP ${NODE_NAME[$i]}.yaml |awk '{print $2}'`
    NODE_ROLE[${#NODE_ROLE[*]}]=`egrep Roles ${NODE_NAME[$i]}.yaml | awk '{print $2}'`

    ## 主机资源使用
    NODE_CPU_PERCENT[${#NODE_CPU_PERCENT[*]}]=`cat ${NODE_NAME[$i]}/Node_Info.json | jq .Percent.CPU | awk -F '.' '{print $1}'`
    NODE_MEM_PERCENT[${#NODE_MEM_PERCENT[*]}]=`cat ${NODE_NAME[$i]}/Node_Info.json | jq .Percent.Mem | awk -F '.' '{print $1}'`
    NODE_DISK_PERCENT[${#NODE_DISK_PERCENT[*]}]=`cat ${NODE_NAME[$i]}/Node_Info.json | jq .Percent.Disk | awk -F '.' '{print $1}'`
    NODE_SWAP_PRECENT[${#NODE_SWAP_PRECENT[*]}]=`cat ${NODE_NAME[$i]}/Node_Info.json | jq .Percent.Disk | awk -F '.' '{print $1}'`

    ## 系统版本信息
    NODE_OS[${#NODE_OS[*]}]=`egrep "OS Image" ${NODE_NAME[$i]}.yaml | awk -F ':' '{print $2}'`
    NODE_KERNEL[${#NODE_KERNEL[*]}]=`egrep "Kernel Version" ${NODE_NAME[$i]}.yaml | awk -F ':' '{print $2}'`
    NODE_KUBELET_VERSION[${#NODE_KUBELET_VERSION[*]}]=`egrep "Kubelet Version" ${NODE_NAME[$i]}.yaml | awk -F ':' '{print $2}'`
    NODE_KUBEPROXY_VERSION[${#NODE_KUBEPROXY_VERSION[*]}]=`egrep "Kube-Proxy Version" ${NODE_NAME[$i]}.yaml | awk -F ':' '{print $2}'`
    NODE_DOCKER_VERSION[${#NODE_DOCKER_VERSION[*]}]=`egrep "docker://" ${NODE_NAME[$i]}.yaml | awk -F 'docker://' '{print $2}'`

    ## 核心组件运行情况
    ## 修改Docker_Info.json格式
    sed -i -e "s#\[##g"  -e "s#\]##g" -e "s/^{/[{/" -e "s/}$/}]/" -e "s/}{/},{/g" -e "s#/##g"  ${NODE_NAME[$i]}/Dokcer_Info.json

    ## Pod运行情况
    POD_NUM=`grep Non-terminated ${NODE_NAME[$i]}.yaml | awk '{print $3}' | awk -F '(' '{print $2}'`
    egrep -A $((${POD_NUM}+2)) Non-terminated ${NODE_NAME[$i]}.yaml | egrep -v "Non-terminated Pods|Namespace|---------" > ${NODE_NAME[$i]}/pod.data

    # 节点资源预留/限制使用
    NODE_CPU_REQUEST[${#NODE_CPU_REQUEST[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep cpu | awk '{print $2 " " $3}'`
    NODE_CPU_LIMIT[${#NODE_CPU_LIMIT[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep cpu | awk '{print $4 " " $5}'`
    NODE_MEM_REQUEST[${#NODE_MEM_REQUEST[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep memory | awk '{print $2 " " $3}'`
    NODE_MEM_LIMIT[${#NODE_MEM_LIMIT[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep memory | awk '{print $4 " " $5}'`

    NODE_CPU_REQUEST_PER[${#NODE_CPU_REQUEST_PER[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep cpu | awk '{print $3}'`
    NODE_CPU_LIMIT_PER[${#NODE_CPU_LIMIT_PER[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep cpu | awk '{print $5}'`
    NODE_MEM_REQUEST_PER[${#NODE_MEM_REQUEST_PER[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep memory | awk '{print $3}'`
    NODE_MEM__LIMIT_PER[${#NODE_MEM__LIMIT_PER[*]}]=`grep -A 6 "Allocated resources" ${NODE_NAME[$i]}.yaml| grep memory | awk '{print $5}'`



done

## Output to markdown
cat > Inspection_report.md << EOF
*Copyright 2021, [Rancher Labs (CN)](https://www.rancher.cn/). All Rights Reserved.*

---

[TOC]

# Kubernetes生产集群巡检报告

## 1、主机列表

| 主机名称 | 主机IP | 主机角色 |
| -------- | ------ | -------- |
EOF

for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
do
    echo "| ${NODE_NAME[$i]} | ${NODE_IP[$i]} |  ${NODE_ROLE[$i]} |" >> Inspection_report.md
done

cat >> Inspection_report.md << EOF

## 2、巡检结果

EOF

for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
do
    cat >> Inspection_report.md << EOF
### 节点：${NODE_NAME[$i]}

**主机资源使用**

|              | 使用百分比 | 剩余百分比 |
| ------------ | ---------- | ---------- |
EOF
    echo "| CPU使用情况 | ${NODE_CPU_PERCENT[$i]}% | $((100-${NODE_CPU_PERCENT[$i]}))% |" >> Inspection_report.md
    echo "| 内存使用情况 | ${NODE_MEM_PERCENT[$i]}% | $((100-${NODE_MEM_PERCENT[$i]}))% |" >> Inspection_report.md
    echo "| SWAP使用情况 | ${NODE_SWAP_PRECENT[$i]}% | $((100-${NODE_SWAP_PRECENT[$i]}))% |" >> Inspection_report.md
    echo "| 磁盘使用情况 | ${NODE_DISK_PERCENT[$i]}% | $((100-${NODE_DISK_PERCENT[$i]}))% |" >> Inspection_report.md

    cat >> Inspection_report.md << EOF
**系统版本信息**

| 组件           | 版本 | 建议 |
| -------------- | ---- | ---- |
EOF
    echo "| 操作系统 | ${NODE_OS[$i]} | - |" >> Inspection_report.md
    echo "| 内核版本 | ${NODE_KERNEL[$i]} | - |" >> Inspection_report.md
    echo "| Kubelet版本 | ${NODE_KUBELET_VERSION[$i]} | - |" >> Inspection_report.md
    echo "| Kube-proxy版本 | ${NODE_KUBEPROXY_VERSION[$i]} | - |" >> Inspection_report.md
    echo "| Docker版本 | ${NODE_DOCKER_VERSION[$i]} | - |" >> Inspection_report.md


    cat >> Inspection_report.md << EOF
**核心组件运行情况**

| 组件            | 启动时间 | 运行状态 | 建议 |
| --------------- | -------- | -------- | ---- |
EOF
    ETCD_STATUS=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "etcd" then $item.DockerStatus else empty end )  ]' | awk -F '"' 'NR==2{print $2}'` > /dev/null 2>&1
    ETCD_STATE=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "etcd" then $item.DockerState else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    API_STATUS=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-apiserver" then $item.DockerStatus else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    API_STATE=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-apiserver" then $item.DockerState else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    CM_STATUS=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-controller-manager" then $item.DockerStatus else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    CM_STATE=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-controller-manager" then $item.DockerState else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    SCHEDULER_STATUS=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-scheduler" then $item.DockerStatus else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    SCHEDULER_STATE=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-scheduler" then $item.DockerState else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    KUBELET_STATUS=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kubelet" then $item.DockerStatus else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    KUBELET_STATE=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kubelet" then $item.DockerState else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    KUBEPROXY_STATUS=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-proxy" then $item.DockerStatus else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`
    KUBEPROXY_STATE=`cat ${NODE_NAME[$i]}/Dokcer_Info.json | jq '[foreach .[] as $item([[],[]]; if $item.DockerName == "kube-proxy" then $item.DockerState else empty end )  ]' | awk -F '"' 'NR==2{print $2}'`

    echo "| etcd | ${ETCD_STATUS} | ${ETCD_STATE} |      |" >> Inspection_report.md
    echo "| kube-apiserver | ${API_STATUS} | ${API_STATE} |      |" >> Inspection_report.md
    echo "| kube-controller-manager | ${CM_STATUS} | ${CM_STATE} |      |" >> Inspection_report.md
    echo "| kube-scheduler | ${SCHEDULER_STATUS} | ${SCHEDULER_STATE} |      |" >> Inspection_report.md
    echo "| kubelet | ${KUBELET_STATUS} | ${KUBELET_STATE} |      |" >> Inspection_report.md
    echo "| kube-proxy | ${KUBEPROXY_STATUS} | ${KUBEPROXY_STATE} |      |" >> Inspection_report.md

    cat >> Inspection_report.md << EOF

**Pod运行情况**

| 命名空间 | Pod名称 | CPU预留 | CPU限制 | 内存预留 | 内存限制 |
| -------- | ------- | ------- | ------- | -------- | -------- |
EOF
    POD=`cat ${NODE_NAME[$i]}/pod.data| wc -l`
    for p in `seq 0 $(($POD-1))`
    do
        NS[$p]=`cat ${NODE_NAME[$i]}/pod.data |awk -v p=$(($p+1)) 'NR==p{print $1}'`
        POD_NAME[$p]=`cat ${NODE_NAME[$i]}/pod.data |awk -v p=$(($p+1)) 'NR==p{print $2}'`
        CPU_REQUEST[$p]=`cat ${NODE_NAME[$i]}/pod.data |awk -v p=$(($p+1)) 'NR==p{print $3 " " $4}'`
        CPU_LIMIT[$p]=`cat ${NODE_NAME[$i]}/pod.data |awk -v p=$(($p+1)) 'NR==p{print $5 " " $6}'`
        MEM_REQUEST[$p]=`cat ${NODE_NAME[$i]}/pod.data |awk -v p=$(($p+1)) 'NR==p{print $7 " " $8}'`
        MEM_LIMIT[$p]=`cat ${NODE_NAME[$i]}/pod.data |awk -v p=$(($p+1)) 'NR==p{print $9 " " $10}'`
        echo "| ${NS[$p]} | ${POD_NAME[$p]} | ${CPU_REQUEST[$p]} | ${CPU_LIMIT[$p]} | ${MEM_REQUEST[$p]} | ${MEM_LIMIT[$p]} |" >> Inspection_report.md
    done

    cat >> Inspection_report.md << EOF
**节点资源预留/限制使用**

| 资源类型 | 总预留/使用 | 限制/使用 |
| -------- | ----------- | --------- |
EOF

    echo "| CPU | ${NODE_CPU_REQUEST[$i]} | ${NODE_CPU_LIMIT[$i]} |" >> Inspection_report.md
    echo "| 内存 | ${NODE_MEM_REQUEST[$i]} | ${NODE_MEM_LIMIT[$i]} |" >> Inspection_report.md

    cat >> Inspection_report.md << EOF

**节点建议/问题**

EOF
    tmp_num=1
    if [[ ${NODE_SWAP_PRECENT[$i]} -gt 0 ]]
    then
        echo "${tmp_num}. 节点swap分区未关闭，建议关闭此项" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        SWAP_COUNT=$(($SWAP_COUNT+1))

    fi
    if [[ ${NODE_CPU_PERCENT[$i]} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点CPU使用达到${NODE_CPU_PERCENT[$i]} %，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        CPU_COUNT=$(($CPU_COUNT+1))
    fi
    if [[ ${NODE_MEM_PERCENT[$i]} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点内存使用达到${NODE_MEM_PERCENT[$i]} %，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        MEM_COUNT=$(($MEM_COUNT+1))
    fi
    if [[ ${NODE_DISK_PERCENT[$i]} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点磁盘使用达到${NODE_DISK_PERCENT[$i]} %，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        DISK_COUNT=$(($DISK_COUNT+1))
    fi

    if [[ ${NODE_CPU_REQUEST_PER[$i]:1:-2} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点CPU资源预留（request）达到${NODE_CPU_REQUEST_PER[$i]:1:-1} ，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        CPU_REQUEST_COUNT=$(($CPU_REQUEST_COUNT+1))
    fi
    if [[ ${NODE_MEM_REQUEST_PER[$i]:1:-2} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点内存资源预留（request）达到${NODE_MEM_REQUEST_PER[$i]:1:-1} ，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        MEM_REQUEST_COUNT=$(($MEM_REQUEST_COUNT+1))
    fi
    if [[ ${NODE_CPU_LIMIT_PER[$i]:1:-2} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点CPU资源限制（limit）达到${NODE_CPU_LIMIT_PER[$i]:1:-1} ，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        CPU_LIMIT_COUNT=$(($CPU_LIMIT_COUNT+1))
    fi
    if [[ ${NODE_MEM__LIMIT_PER[$i]:1:-2} -ge 80 ]]
    then
        echo "${tmp_num}. 截止至巡检日期，节点内存资源限制（limit）达到${NODE_MEM__LIMIT_PER[$i]:1:-1} ，建议合理规划资源" >> Inspection_report.md
        echo "" >> Inspection_report.md
        tmp_num=$(($tmp_num+1))
        MEM_LIMIT_COUNT=$(($MEM_LIMIT_COUNT+1))
    fi




done

cat >> Inspection_report.md << EOF
## 3、巡检汇总

问题总结如下:

1. 集群节点整体负载水平较高;低风险，暂无需扩容节点;

EOF

total_num=1

if [[ $SWAP_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. " >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_SWAP_PRECENT[$i]} -gt 0  ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点均未关闭swap分区，建议关闭此项；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $CPU_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_CPU_PERCENT[$i]} -ge 80  ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点CPU使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $MEM_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_MEM_PERCENT[$i]} -ge 80  ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点内存使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $DISK_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_DISK_PERCENT[$i]} -ge 80  ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点磁盘使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $CPU_REQUEST_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_CPU_REQUEST_PER[$i]:1:-2} -ge 80 ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点CPU资源预留（request）使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $MEM_REQUEST_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_MEM_REQUEST_PER[$i]:1:-2} -ge 80 ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点内存资源预留（request）使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $CPU_LIMIT_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_CPU_LIMIT_PER[$i]:1:-2} -ge 80 ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点CPU资源限制（limit）使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi

if [[ $MEM_LIMIT_COUNT -gt 0 ]]
then
    total_num=$(($total_num+1))
    echo -n "${total_num}. 截止至巡检日期，" >> Inspection_report.md
    for i in `seq 0 $((${#NODE_NAME[*]} - 1))`
    do
        if [[ ${NODE_MEM__LIMIT_PER[$i]:1:-2} -ge 80 ]]
        then
            echo -n "${NODE_NAME[$i]} " >> Inspection_report.md
        fi    
    done
    echo "节点内存资源限制（limit）使用超过80%，建议合理规划资源；" >> Inspection_report.md
    echo "" >> Inspection_report.md
fi
