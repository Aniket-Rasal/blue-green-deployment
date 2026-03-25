pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/Aniket-Rasal/blue-green-deployment.git'
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t bluegreen-app ./app/v1'
            }
        }

        stage('Deploy') {
            steps {
                sh '''
                chmod +x scripts/*.sh
                ./scripts/deploy.sh
                '''
            }
        }
    }
}
