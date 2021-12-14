#! /bin/bash

## 初始化参数
output_path="./output"
cluster_output_path="./cluster_output"
rancherinfo_log="${output_path}/rancherinfo.log"

nodeinfo_output="./nodeinfo"

report_output_path="report.md"

## start output
start_output() {
    cat > ${report_output_path} << EOF
*Copyright 2021, [Rancher Labs (CN)](https://www.rancher.cn/). All Rights Reserved.*


[TOC]

# Rancher容器云平台巡检报告
EOF
}

## Rancher
## output Rancher基本信息
output_rancher() {
    rancher_version=$(cat ${rancherinfo_log} | grep rancher_version | awk '{print $2}')
    rancher_install_mode=$(cat ${rancherinfo_log} | grep rancher_install_mode | awk '{print $2}')
    rancher_pods_num=$(cat ${rancherinfo_log} | grep rancher_pods_num | awk '{print $2}')
    rancher_phase=$(cat ${rancherinfo_log} | grep "^  rancher:" -A 2 | grep phase | awk '{print $2}')
    clusters_num=$(cat ${rancherinfo_log} | grep "clusters_num" | awk '{print $2}')
    user_num=$(cat ${rancherinfo_log} | grep "user_num" | awk '{print $2}')
    prtb_num=$(cat ${rancherinfo_log} | grep "prtb_num" | awk '{print $2}')
    crtb_num=$(cat ${rancherinfo_log} | grep "crtb_num" | awk '{print $2}')
    cat >> ${report_output_path} << EOF

### Cluster基本信息

| 检查项 | 结果 |
| ----- | --- |
| Rancher版本 | ${rancher_version} |
| Rancher install mode | ${rancher_install_mode} |
| Rancher副本数 | ${rancher_pods_num} |
| Rancher状态 | ${rancher_phase} |
| 集群数量 | ${clusters_num} |
| 用户数量 | ${user_num} |
| prtb | ${prtb_num} |
| crtb | ${crtb_num} |

EOF
}

## output Cluster基本信息
output_cluster() {
    cat >> ${report_output_path} << EOF
## 1、Rancher信息

### Rancher基本信息

| 名称 | ID   | k8s版本 | 节点数 | 集群监控 | 集群告警 | 集群直连 |
| ---- | ---- | ------- | ------ | -------- | -------- | -------- |
EOF
    for i in $(ls ${output_path}/cluster );do
        cluster_name=$(cat ${output_path}/cluster/$i | jq -r .name )
        cluster_id=$(cat ${output_path}/cluster/$i | jq -r .id )
        cluster_k8s_version=$(cat ${output_path}/cluster/$i | jq -r .version.gitVersion)
        cluster_nodes_num=$(cat ${rancherinfo_log} | grep "  ${cluster_id}:" -A 3 | grep nodes_num | awk '{print $2}')
        cluster_monitoring=$(cat ${rancherinfo_log} | grep "  ${cluster_id}:" -A 4 | grep cluster_monitoring | awk '{print $2}')
        cluster_alerting=$(cat ${rancherinfo_log} | grep "  ${cluster_id}:" -A 5 | grep cluster_alerting | awk '{print $2}')
        is_direct=$(cat ${rancherinfo_log} | grep "  ${cluster_id}:" -A 8 | grep is_direct | awk '{print $2}')

        echo "| ${cluster_name} | ${cluster_id} | ${cluster_k8s_version} | ${cluster_nodes_num} | ${cluster_monitoring} | ${cluster_alerting} | ${is_direct} |" >> ${report_output_path}
    done
}

## output rancher chart values
output_rancher_chart() {
    if [[ -f ${output_path}/rancher_values.yaml ]];then
        cat >> ${report_output_path} << EOF

### Rancher Chart Value

\`\`\`bash
$(cat ${output_path}/rancher_values.yaml)
\`\`\`

EOF
    fi
}

## downstream k8s cluster
k8s_output() {
    cat >> ${report_output_path} << EOF
## 2、下游k8s集群信息

EOF
}

## node list
k8s_node_output() {
    cluster_id=$1
    cluster_name=$(cat ${output_path}/cluster/cluster_${cluster_id}.json | jq -r .name)
    cat >> ${report_output_path} << EOF
### 集群：${cluster_name}

#### 节点列表

| 主机名 | 主机IP | 主机角色 |
| ------ | ------ | -------- |
EOF
    for i in `ls ${cluster_output_path}/${cluster_id}/ | grep -v "^cluster_info"`;do
        node_name=$(echo $i | awk -F '.' '{print $1}')
        node_IP=$(cat ${cluster_output_path}/${cluster_id}/${i} | grep "  InternalIP:" | awk '{print $2}')
        node_role=$(cat ${cluster_output_path}/${cluster_id}/${i} | grep "Roles:" | awk '{print $2}')
        echo "| ${node_name} | ${node_IP} | ${node_role} |" >> ${report_output_path}
    done
    echo "" >> ${report_output_path}
}

## output rke k8s config
k8s_rke_config_output(){
    cluster_id=$1
    echo "#### rke cluster.yml配置" >>  ${report_output_path}
    driver=$(cat output/cluster/cluster_c-gjww2.json | jq -r .driver)
    ## 判断是否为空
    if [[ $driver != "rancherKubernetesEngine" ]];then
        echo "**非自定义集群，无cluster.yml相关配置。**" >> ${report_output_path}
        return
    fi
    ## 输出cluster.yml中k8s组件的配置
    kube_c=(etcd kubeApi kubeController scheduler kubelet kubeproxy)
    for kube in `seq 0 $((${#kube_c[*]} - 1))`;do
        cat >> ${report_output_path} << EOF
**${kube_c[${kube}]} config**
\`\`\`
$(cat ${output_path}/cluster/cluster_${cluster_id}.json | jq .appliedSpec.rancherKubernetesEngineConfig.services.${kube_c[${kube}]})
\`\`\`

EOF
    done
    ## 输出网络配置
    cat >> ${report_output_path} << EOF
**network config**
\`\`\`
$(cat ${output_path}/cluster/cluster_${cluster_id}.json | jq .appliedSpec.rancherKubernetesEngineConfig.network)
\`\`\`

EOF
}

## cert exp
k8s_cert_exp(){
    cluster_id=$1
    ## 证书到期时间
    cat >> ${report_output_path} << EOF
#### 证书到期时间
| 组件 | 到期时间 |
| ---- | -------- |
EOF
    kube_c_exp=(kube-ca kube-apiserver kube-controller-manager kube-scheduler kube-proxy kube-node)
    for kube in `seq 0 $((${#kube_c_exp[*]} - 1))`;do
        echo "| ${kube_c_exp[${kube}]} | $(cat ${output_path}/cluster/cluster_${cluster_id}.json | jq -r .certificatesExpiration.\"${kube_c_exp[${kube}]}\".expirationDate) |" >> ${report_output_path}
    done
}

## #### k8s resources usage
k8s_resources_usage() {
    cluster_id=$1
     cat >> ${report_output_path} << EOF
**Native_resources TOP 5**
| 名称 | 数量 |
| ---- | ---- |
EOF
    cat ${cluster_output_path}/${cluster_id}/cluster_info_${cluster_id}.txt | grep native_reources -A 5 | awk  'NR>1 {print "| "$2" | "$1" |"}' >> ${report_output_path}
    echo "" >> ${report_output_path}
    cat >> ${report_output_path} << EOF
**CRD_resources TOP 5**
| 名称 | 数量 |
| ---- | ---- |
EOF
    cat ${cluster_output_path}/${cluster_id}/cluster_info_${cluster_id}.txt | grep crd_reources -A 5 | awk  'NR>1 {print "| "$2" | "$1" |"}' >> ${report_output_path}
    echo "" >> ${report_output_path}
}

## node
node_output() {
cat >> ${report_output_path} << EOF
#### 节点巡检

EOF
}
node_info() {
    cluster_id=$1
    node=$2
    cat >> ${report_output_path} << EOF
**系统版本信息**

| 组件 | 版本 | 建议 |
| --- | --- | --- |
EOF
    sys_version=$(cat ${cluster_output_path}/${cluster_id}/${node}.txt | grep "OS Image" | awk -F ':' '{print $2}')
    kernel_version=$(cat ${cluster_output_path}/${cluster_id}/${node}.txt | grep "Kernel Version" | awk -F ':' '{print $2}')
    kubelet_version=$(cat ${cluster_output_path}/${cluster_id}/${node}.txt | grep "Kubelet Version" | awk -F ':' '{print $2}')
    kubeproxy_version=$(cat ${cluster_output_path}/${cluster_id}/${node}.txt | grep "Kube-Proxy Version" | awk -F ':' '{print $2}')
    docker_version=$(cat ${cluster_output_path}/${cluster_id}/${node}.txt | grep "docker://" | awk -F 'docker://' '{print $2}')
    cat >> ${report_output_path} << EOF
| 操作系统 | ${sys_version} | - |
| 内核版本 | ${kernel_version} | - |
| Kubelet版本 | ${kubelet_version} | - |
| kubeproxy版本 | ${kubeproxy_version} | - |
| docker版本 | ${docker_version} | - |
EOF
}

## 节点资源预留/限制
node_resource_limit(){
    cluster_id=$1
    node=$2

    CPU_request=$(grep -A 6 "Allocated resources" ${cluster_output_path}/${cluster_id}/${node}.txt | grep cpu | awk '{print $2 " " $3}')
    CPU_limit=$(grep -A 6 "Allocated resources" ${cluster_output_path}/${cluster_id}/${node}.txt | grep cpu | awk '{print $4 " " $5}')
    mem_request=$(grep -A 6 "Allocated resources" ${cluster_output_path}/${cluster_id}/${node}.txt | grep memory | awk '{print $2 " " $3}')
    mem_limit=$(grep -A 6 "Allocated resources" ${cluster_output_path}/${cluster_id}/${node}.txt | grep memory | awk '{print $4 " " $5}')

    cat >> ${report_output_path} << EOF
**节点资源预留/限制使用**

| 资源类型 | 总预留/使用 | 限制/使用  |
| --- | --- | --- |
| CPU | ${CPU_request} | ${CPU_limit} |
| memory | ${mem_request} | ${mem_limit} |
EOF
}

## pod运行情况
node_pod(){
    cluster_id=$1
    node=$2

    pod_num=$(grep Non-terminated  ${cluster_output_path}/${cluster_id}/${node}.txt | awk '{print $3}' | awk -F '(' '{print $2}')
    cat >> ${report_output_path} << EOF
**Pod运行情况**

| 命名空间 | Pod名称 | CPU预留 | CPU限制 | 内存预留 | 内存限制 |
| ------- | ------ | ------ | ------- | ------ | ------- |
$(egrep -A $((${pod_num}+2)) Non-terminated  ${cluster_output_path}/${cluster_id}/${node}.txt | awk 'NR>3 {print "| "$1" | "$2 " | "$3" "$4" | "$5" "$6" | "$7" "$8" | "$9" "$10" |"}')

EOF
}

## 圆形图 get_pie_chart ${NODE_CPU_PERCENT[$i]} 100 CPU
get_pie_chart(){
    usage=$1
    position=$2
    name=$3
    if [[ $1 -lt 50 ]]
    then
        LARGE_ARC_FLAG=0
    else
        LARGE_ARC_FLAG=1
    fi
        r=50
        c_x=${position}
        c_y=95
        angle=`echo "scale=10; ${usage} * 360 / 100"| bc -l`
        x=`echo "scale=10; ${r} * s(${angle} * 3.14 / 180 )"| bc -l`
        y=`echo "scale=10;${r} - ( ${r} * c(${angle} * 3.14 / 180 ) )"| bc -l`
        text_x=$(($c_x-30))
        echo "<text x='${c_x}' y='$((c_y-60))' font-size="20" text-anchor='middle'>${name}使用率</text>"
        echo "<circle cx='${c_x}' cy='${c_y}' r='${r}'  fill='#FFA500'/>"
        echo "<path d = 'M ${c_x},${c_y} v-${r} a${r},${r} 0 ${LARGE_ARC_FLAG},1 ${x},${y} ' fill='#1C86EE'/>"
        echo "<circle cx='${c_x}' cy='${c_y}' r='$(($r-15))'  fill='white'/>"
        echo "<text x='${c_x}' y='$((c_y+8))' font-size="22" text-anchor='middle' font-weight='bold'>${usage}%</text>"
}

## node resources usage
node_resources_usage() {
    cluster_id=$1
    node=$2
    CPU_per=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .CPU.Percent |  awk -F '.' '{print $1}')
    mem_per=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .Memory.Percent |  awk -F '.' '{print $1}')
    swap_per=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .Swap.Percent |  awk -F '.' '{print $1}')
    disk_per=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .Disk.Percent |  awk -F '.' '{print $1}')
    cat >> ${report_output_path} << EOF
**主机资源使用**

<svg width='850' height='180'>
$(get_pie_chart ${CPU_per} 100 CPU)
$(get_pie_chart ${mem_per} 300 Memory)
$(get_pie_chart ${swap_per} 500 SWAP)
$(get_pie_chart ${disk_per} 700 Disk)
</svg>

EOF
}

## node Load
node_load(){
    cluster_id=$1
    node=$2
    load1=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .CPU.Load.load1)
    load5=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .CPU.Load.load5)
    load15=$(cat ${nodeinfo_output}/${node}/nodeinfo.json | jq .CPU.Load.load15)
    cat >> ${report_output_path} << EOF
**Load**

| Load1 | Load5 | Load15 |
| ----- | ----- | ------ |
| ${load1} | ${load5} | ${load15} |

EOF
}

## node Docker info
node_docker_info() {
    cluster_id=$1
    node=$2
    docker_verion=$(cat ${nodeinfo_output}/${node}/docker_info.log | grep "Server Version" | awk -F ':' '{print $2}')
    cgroup_driver=$(cat ${nodeinfo_output}/${node}/docker_info.log | grep "Cgroup Driver" | awk -F ':' '{print $2}')
    storage_driver=$(cat ${nodeinfo_output}/${node}/docker_info.log | grep "Storage Driver" | awk -F ':' '{print $2}')
    default_runtime=$(cat ${nodeinfo_output}/${node}/docker_info.log | grep "Default Runtime" | awk -F ':' '{print $2}')
    cat >> ${report_output_path} << EOF
**Docker信息**

| 检查项           | 结果     |
| ---------------- | -------- |
| Docker版本 | ${docker_verion} |
| Cgroup Driver | ${cgroup_driver} |
| Storage Driver | ${storage_driver} |
| Default Runtimes | ${default_runtime} |
EOF
}

## node limit
node_limit(){
    cluster_id=$1
    node=$2
    limit=$(cat ${nodeinfo_output}/${node}/limit-a.log  | grep "open files" | awk '{print $4}')
    cat >> ${report_output_path} << EOF
**limits**

| 检查项    | 结果 |
| --------- | ---- |
| open files | ${limit} |

EOF
    limit_conf=$(cat ${nodeinfo_output}/${node}/limits.conf | egrep -v "#|^$")
    if [[ ${limit_conf} != "" ]];then
        cat >> ${report_output_path} << EOF
**Limits.conf**

\`\`\`
$(cat ${nodeinfo_output}/${node}/limits.conf | egrep -v "#|^$")
\`\`\`
EOF
    else
        cat >> ${report_output_path} << EOF
**Limits.conf**
未配置limit

EOF
fi
}

node_zombie_process(){
    cluster_id=$1
    node=$2
    zombie_process=$(cat ${nodeinfo_output}/${node}/ps_info.log | grep defunct)
    if [[ ${zombie_process} != "" ]];then
        cat >> ${report_output_path} << EOF
**僵尸进程**

\`\`\`bash
cat ${nodeinfo_output}/${node}/ps_info.log | grep defunct
\`\`\`
EOF
    else
        cat >> ${report_output_path} << EOF
**僵尸进程**
未发现僵尸进程

EOF
    fi
}

## node sysctls
node_sysctls(){
    cluster_id=$1
    node=$2
    KERNEL_VARIABLES=("net.ipv4.ip_forward"
        "net.ipv6.conf.all.disable_ipv6"
        "net.ipv6.conf.default.disable_ipv6"
        "fs.file-max"
        "net.core.rmem_max"
        "net.core.wmem_max"
        "vm.max_map_count"
        "net.ipv4.tcp_slow_start_after_idle"
        "net.core.netdev_max_backlog"
        "fs.inotify.max_user_instances"
        "fs.inotify.max_user_watches"
        "net.ipv4.tcp_max_syn_backlog"
        "net.ipv4.tcp_tw_reuse"
        "net.ipv4.ip_local_port_range"
        "net.ipv4.tcp_max_tw_buckets"
        "net.core.somaxconn"
        "net.ipv4.neigh.default.gc_thresh1"
        "net.ipv4.neigh.default.gc_thresh2"
        "net.ipv4.neigh.default.gc_thresh3"
        "net.ipv4.tcp_rmem"
        "net.ipv4.tcp_wmem"
        "vm.overcommit_memory"
        "kernel.panic"
        "kernel.panic_on_oops"
        "kernel.softlockup_panic"
        "kernel.softlockup_all_cpu_backtrace"
        )
    cat >> ${report_output_path} << EOF
**内核参数**

| 检查项 | 结果 |
| --- | --- |
$(for k_var in ${KERNEL_VARIABLES[@]};do
    cat ${nodeinfo_output}/${node}/sysctl.log | grep ${k_var} | awk -F ' = ' '{print "| "$1" | "$2" |"}'
done
)

EOF
}

## node kube component status
node_kube_status(){
    cluster_id=$1
    node=$2
    cat >> ${report_output_path} << EOF
**核心组件运行情况**

| 组件 | 启动时间 | 运行状态 | 建议 |
| --- | --- | --- | --- |
EOF
    kube_component=(etcd kube-apiserver kube-controller-manager kube-scheduler kubelet kube-proxy nginx-proxy)
    for k_var in ${kube_component[@]};do
        c_status=$(cat nodeinfo/node01/nodeinfo.json |  jq --arg xxx ${k_var} '[foreach .Docker[] as $item([[],[]]; if $item.Name == $xxx then $item.Status else empty end )  ]' | awk -F '"' 'NR==2{print $2}')
        c_running=$(cat nodeinfo/node01/nodeinfo.json |  jq --arg xxx ${k_var} '[foreach .Docker[] as $item([[],[]]; if $item.Name == $xxx then $item.Running else empty end )  ]' | awk -F '"' 'NR==2{print $2}')
        if [[ ${c_status} != "" ]];then
            echo "| ${k_var} | ${c_status} | ${c_running} | - |" >> ${report_output_path}
        fi
    done
}

if [[ $1 == "" ]];then
    start_output
    ## Rancher info
    output_rancher
    output_cluster
    output_rancher_chart

    ## downstream k8s cluster
    k8s_output
    for cluster in `ls ${cluster_output_path}`;do
        k8s_node_output ${cluster}
        k8s_rke_config_output ${cluster}
        k8s_cert_exp ${cluster}
        k8s_resources_usage ${cluster}
    

        ## node
        node_output
        for n in `ls ${cluster_output_path}/${cluster}/ | grep -v "^cluster_info"`;do
            node=$(echo $n | awk -F '.' '{print $1}')
            node_info ${cluster} ${node}
            node_resource_limit ${cluster} ${node}
            node_pod ${cluster} ${node}
            node_resources_usage ${cluster} ${node}
            node_load ${cluster} ${node}
            node_docker_info ${cluster} ${node}
            node_limit ${cluster} ${node}
            node_zombie_process ${cluster} ${node}
            node_sysctls ${cluster} ${node}
            node_kube_status ${cluster} ${node}
        done
    done

else
    echo "No parameters are required"
fi