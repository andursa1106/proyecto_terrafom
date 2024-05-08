pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-west2'
        TERRAFORM_EXECUTABLE = '/home/jenkins/terraform/terraform'
        CREDENTIALS_ID = 'AWS_ACCESS_KEY_ID'
        SECRET_CREDENTIALS_ID = 'AWS_SECRET_ACCESS_KEY'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Init') {
            steps {
                script {
                    try {
                        withCredentials([string(credentialsId: env.CREDENTIALS_ID, variable: 'AWS_ACCESS_KEY_ID'),
                                         string(credentialsId: env.SECRET_CREDENTIALS_ID, variable: 'AWS_SECRET_ACCESS_KEY')]) {
                            sh "${env.TERRAFORM_EXECUTABLE} init -no-color"
                        }
                    } catch (Exception e) {
                        echo "Mensaje de error: ${e}"
                        currentBuild.result = 'FAILURE'
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                script {
                    try {
                        withCredentials([string(credentialsId: env.CREDENTIALS_ID, variable: 'AWS_ACCESS_KEY_ID'),
                                         string(credentialsId: env.SECRET_CREDENTIALS_ID, variable: 'AWS_SECRET_ACCESS_KEY')]) {
                            sh "${env.TERRAFORM_EXECUTABLE} plan -no-color"
                        }
                    } catch (Exception e) {
                        echo "Mensaje de error: ${e}"
                        currentBuild.result = 'FAILURE'
                    }
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                script {
                    try {
                        withCredentials([string(credentialsId: env.CREDENTIALS_ID, variable: 'AWS_ACCESS_KEY_ID'),
                                         string(credentialsId: env.SECRET_CREDENTIALS_ID, variable: 'AWS_SECRET_ACCESS_KEY')]) {
                            sh "${env.TERRAFORM_EXECUTABLE} apply --auto-approve -no-color"
                        }
                    } catch (Exception e) {
                        echo "Mensaje de error: ${e}"
                        currentBuild.result = 'FAILURE'
                    }
                }
            }
        }

        stage('Destroy Terraform Resources') {
            steps {
                script {
                    try {
 
                        input message: '¿Quieres destruir los recursos de Terraform?', ok: 'Destruir'
                        withCredentials([string(credentialsId: env.CREDENTIALS_ID, variable: 'AWS_ACCESS_KEY_ID'),
                                         string(credentialsId: env.SECRET_CREDENTIALS_ID, variable: 'AWS_SECRET_ACCESS_KEY')]) {
                            sh "${env.TERRAFORM_EXECUTABLE} destroy --auto-approve  -no-color"
                        }
                    } catch (Exception e) {
                        echo "Mensaje de error: ${e}"
                        currentBuild.result = 'FAILURE'
                    }
                }
            }
        }
    }
}


     


/*
pipeline {
  
    agent any

    stages {
  
        stage('Terraform version') {
            steps {
                script {
                    sh '/home/jenkins/terraform/terraform -version'
                }
            }
        }
    }
}

*/
