variable "artifact_description" {
  type    = string
  default = "Rocky 9.1 with 6.x kernel"
}
variable "artifact_version" {
  type    = string
  default = "9.1"
}
variable "headless" {
  type    = string
  default = "true"
}
variable "shutdown_command" {
  type    = string
  default = "sudo -S /sbin/halt -h -p"
}
variable "iso_url" {
  type = string
  default = "file:///home/kgeor/Downloads/Rocky-9.1-x86_64-minimal.iso"
}
variable "iso_checksum" {
  type = string
  default = "bae6eeda84ecdc32eb7113522e3cd619f7c8fc3504cb024707294e3c54e58b40"
}
variable "output_directory" {
  type = string
  default = "./builds"
}

source "virtualbox-iso" "virtualbox" {
  boot_command          = ["<tab> text inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg<enter><wait>"]
  boot_wait             = "10s"
  disk_size             = "16000"
  export_opts           = ["--manifest",
  "--vsys", "0",
  "--description", "${var.artifact_description}",
  "--version", "${var.artifact_version}"
  ]
  guest_os_type         = "RedHat_64"
  hard_drive_interface  = "sata"
  headless              = "${var.headless}"
  http_directory        = "http"
  iso_checksum          = "sha256:${var.iso_checksum}"
  iso_url               = "${var.iso_url}"
  output_directory      = "builds"
  ssh_password          = "vagrant"
  ssh_timeout           = "20m"
  ssh_username          = "vagrant"
  shutdown_command      = "${var.shutdown_command}"
  shutdown_timeout      = "5m"
  vboxmanage            = [
    [ "modifyvm", "{{ .Name }}", "--memory", "2048"],
    [ "modifyvm", "{{ .Name }}", "--cpus", "2" ],
    [ "modifyvm", "{{ .Name }}", "--nat-localhostreachable1", "on"],
    [ "modifyvm", "{{ .Name }}", "--rtcuseutc", "on"],
    [ "modifyvm", "{{ .Name }}", "--graphicscontroller", "vmsvga"],
    [ "modifyvm", "{{ .Name }}", "--vram", "16"],
    [ "modifyvm", "{{ .Name }}", "--nictype1", "82545EM"]
  ]
  vm_name               = "rocky9-packer"
}

build {
  sources = ["source.virtualbox-iso.virtualbox"]
  provisioner "shell" {
    execute_command     = "sudo {{ .Vars }} bash {{ .Path }}"
    expect_disconnect   = "true"
    pause_after         = "30s"
    scripts             = ["scripts/stage-1-update.sh"]
  }
  provisioner "shell" {
    execute_command     = "sudo {{ .Vars }} bash {{ .Path }}"
    scripts             = ["scripts/stage-2-vbox-guest.sh"]
  }

  post-processor "vagrant" {
    compression_level   = "7"
    output              = "Rocky${var.artifact_version}-x86_64-base.box"
  }
}