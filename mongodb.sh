user_data = <<-EOF
              #!/bin/bash
              # Update and install prerequisites
              apt-get update -y
              apt-get install -y dirmngr gnupg apt-transport-https ca-certificates software-properties-common

              # Add MongoDB GPG key and repository for version 7.0
              wget -qO - https://www.mongodb.org/static/pgp/server-7.0.asc | apt-key add -
              echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list

              # Install MongoDB
              apt-get update
              apt-get install -y mongodb-org

              # Enable and start MongoDB service
              systemctl enable mongod
              systemctl start mongod

              # Check if MongoDB is running
              if systemctl status mongod | grep -q "active (running)"; then
                echo "MongoDB installation and setup completed successfully."
              else
                echo "MongoDB failed to start. Reloading systemctl daemon and restarting MongoDB..."
                systemctl daemon-reload
                systemctl start mongod

                if systemctl status mongod | grep -q "active (running)"; then
                    echo "MongoDB is now running."
                else
                    echo "Failed to start MongoDB. Please check the logs for more details."
                fi
              fi
            EOF
