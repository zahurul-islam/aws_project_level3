# Local file for WordPress user data script
locals {
  wordpress_userdata = base64encode(templatefile("${path.module}/userdata/wordpress-userdata.sh", {
    db_host     = var.enable_rds ? aws_db_instance.main[0].endpoint : "localhost"
    db_name     = var.wordpress_db_name
    db_user     = var.wordpress_db_username
    db_password = var.wordpress_db_password
    enable_rds  = var.enable_rds
  }))

  bastion_userdata = base64encode(templatefile("${path.module}/userdata/bastion-userdata.sh", {}))
}
