resource "null_resource" "hana_node_provisioner" {
  count = var.provisioner == "salt" ? var.hana_count : 0

  triggers = {
    cluster_instance_ids = join(",", aws_instance.clusternodes.*.id)
  }

  connection {
    host        = element(aws_instance.clusternodes.*.public_ip, count.index)
    type        = "ssh"
    user        = "ec2-user"
    private_key = file(var.private_key_location)
  }

  provisioner "file" {
    source      = var.aws_access_key_id == "" || var.aws_secret_access_key == "" ? var.aws_credentials : "/dev/null"
    destination = "/tmp/credentials"
  }

  provisioner "file" {
    source      = "../salt"
    destination = "/tmp/salt"
  }

  provisioner "file" {
    content = <<EOF
provider: aws
region: ${var.aws_region}
role: hana_node
aws_cluster_profile: Cluster
aws_instance_tag: Cluster
aws_credentials_file: /tmp/credentials
aws_access_key_id: ${var.aws_access_key_id}
aws_secret_access_key: ${var.aws_secret_access_key}
hana_cluster_vip: ${var.hana_cluster_vip}
route_table: ${var.route_table_id}
scenario_type: ${var.scenario_type}
name_prefix: ${terraform.workspace}-${var.name}
host_ips: [${join(", ", formatlist("'%s'", var.host_ips))}]
hostname: ${terraform.workspace}-${var.name}${var.hana_count > 1 ? "0${count.index + 1}" : ""}
network_domain: "tf.local"
shared_storage_type: iscsi
sbd_disk_device: /dev/sda
hana_inst_master: ${var.hana_inst_master}
hana_inst_folder: ${var.hana_inst_folder}
hana_disk_device: ${var.hana_disk_device}
hana_fstype: ${var.hana_fstype}
iscsi_srv_ip: ${var.iscsi_srv_ip}
init_type: ${var.init_type}
cluster_ssh_pub:  ${var.cluster_ssh_pub}
cluster_ssh_key: ${var.cluster_ssh_key}
reg_code: ${var.reg_code}
reg_email: ${var.reg_email}
reg_additional_modules: {${join(", ", formatlist("'%s': '%s'", keys(var.reg_additional_modules), values(var.reg_additional_modules)))}}
additional_packages: [${join(", ", formatlist("'%s'", var.additional_packages))}]
ha_sap_deployment_repo: ${var.ha_sap_deployment_repo}
monitoring_enabled: ${var.monitoring_enabled}
devel_mode: ${var.devel_mode}
qa_mode: ${var.qa_mode}
hwcct: ${var.hwcct}
EOF

    destination = "/tmp/grains"
  }

  provisioner "remote-exec" {
    inline = [
      "${var.background ? "nohup" : ""} sudo sh /tmp/salt/provision.sh > /tmp/provisioning.log ${var.background ? "&" : ""}",
      "return_code=$? && sleep 1 && exit $return_code",
    ] # Workaround to let the process start in background properly
  }
}
