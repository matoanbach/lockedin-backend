pipeline {
    agent any
    environment {
        GITHUB_TOKEN=credentials('github-token')
        IMAGE_NAME='matoanbach/lockedin-backend'
        IMAGE_VERSION='9.2-205'
    }

    stages {
        stage("Build the image") {
            steps {
                echo "Build the image ..."
                sh 'docker build -t $IMAGE_NAME:$IMAGE_VERSION ./backend'
            }
        }
        stage("Login to GHCR") {
            steps {
                sh 'echo $GITHUB_TOKEN_PSW | docker login ghcr.io -u $GITHUB_TOKEN_USR --password-stdin'
            }
        }
        stage("Tag image") {
            steps {
                sh 'docker tag $IMAGE_NAME:$IMAGE_VERSION ghcr.io/$IMAGE_NAME:$IMAGE_VERSION'
            }
        }
        stage("Push image") {
            steps {
                sh 'docker push ghcr.io/$IMAGE_NAME:$IMAGE_VERSION'
            }
        }
    }
    post {
        always {
            sh 'docker logout ghcr.io'
        }
    }
}
