variable "artifact_description" {
  type    = string
  default = "Rocky 9.2 with 6.x kernel"
}
variable "artifact_version" {
  type    = string
  default = "9.2"
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
  default = "file:///home/kgeor/Downloads/Rocky-9.2-x86_64-minimal.iso"
}
variable "iso_checksum" {
  type = string
  default = "06505828e8d5d052b477af5ce62e50b938021f5c28142a327d4d5c075f0670dc"
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
  guest_os_type         = "RedHat9_64"
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
  vm_name               = "Rocky9-packer"
}

build {
  sources = ["source.virtualbox-iso.virtualbox"]
  provisioner "shell" {
    execute_command     = "sudo {{ .Vars }} bash {{ .Path }}"
    expect_disconnect   = "true"
    pause_after         = "20s"
    scripts             = ["scripts/stage-1-update.sh"]
  }
  provisioner "shell" {
    execute_command     = "sudo {{ .Vars }} bash {{ .Path }}"
    expect_disconnect   = "true"
    pause_after         = "20s"
    scripts             = ["scripts/stage-2-vbox-guest.sh"]
  }
  provisioner "shell" {
    execute_command     = "sudo {{ .Vars }} bash {{ .Path }}"
    scripts             = ["scripts/stage-3-cleanup.sh"]
  }

  post-processor "vagrant" {
    compression_level   = "7"
    output              = "Rocky${var.artifact_version}-x86_64-base.box"
  }
}