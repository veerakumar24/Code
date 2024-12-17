user_data = <<-EOF
    #!/bin/bash
    echo "Starting Jenkins installation..." >> /var/log/user_data.log
    sudo apt-get update -y >> /var/log/user_data.log 2>&1
    sudo apt-get install -y openjdk-17-jdk >> /var/log/user_data.log 2>&1

    sudo curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null >> /var/log/user_data.log 2>&1
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list >> /var/log/user_data.log 2>&1

    sudo apt-get update -y >> /var/log/user_data.log 2>&1
    sudo apt-get install -y jenkins >> /var/log/user_data.log 2>&1

    sudo systemctl start jenkins >> /var/log/user_data.log 2>&1
    sudo systemctl enable jenkins >> /var/log/user_data.log 2>&1

    echo "Waiting for Jenkins to initialize..." >> /var/log/user_data.log
    sleep 60

    echo "Configuring Jenkins credentials..." >> /var/log/user_data.log
    sudo mkdir -p /var/lib/jenkins/init.groovy.d

    cat <<GROOVY_SCRIPT | sudo tee /var/lib/jenkins/init.groovy.d/basic-security.groovy > /dev/null
    import jenkins.model.*
    import hudson.security.*

    def instance = Jenkins.getInstance()
    def hudsonRealm = new HudsonPrivateSecurityRealm(false)
    hudsonRealm.createAccount("admin", "admin")
    instance.setSecurityRealm(hudsonRealm)

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    instance.save()
    GROOVY_SCRIPT

    echo "Restarting Jenkins to apply configuration..." >> /var/log/user_data.log
    sudo systemctl restart jenkins >> /var/log/user_data.log 2>&1

    echo "Jenkins installation and configuration completed with username: admin and password: admin." >> /var/log/user_data.log
  EOF
