output "public_ip" {
  value       = aws_instance.app_server.public_ip # Mude para a variável do seu recurso (ex: digitalocean_droplet.ip_address)
  description = "The public IP address of the application server"
}