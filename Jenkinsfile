pipeline {
  agent any

  environment {
    // <-- CHANGE these to match your environment
    AWS_REGION = 'us-east-1'      // change to your AWS region
    ECR_REPO   = 'myapp'           // change to the ECR repo name you want
    APP_NAME   = 'myapp'           // used as the container name locally
    APP_PORT   = '8080'            // port your app exposes
    MAVEN_IMAGE = 'maven:3.9.2-openjdk-17' // maven image used for build/test
  }

  // If you prefer webhook triggers, configure in GitHub and remove pollSCM or keep both
  triggers {
    // githubPush()   // uncomment if you have GitHub plugin + webhook
    pollSCM('H/5 * * * *') // fallback polling (optional)
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Build (compile & package)') {
      steps {
        script {
          // run maven build inside a Maven image so you don't need maven installed on the host
          docker.image(MAVEN_IMAGE).inside {
            sh 'mvn -B -DskipTests clean package'
          }
        }
      }
    }

    stage('Test (unit)') {
      steps {
        script {
          docker.image(MAVEN_IMAGE).inside {
            sh 'mvn -B test'
          }
        }
      }
    }

    stage('SonarQube analysis') {
      steps {
        // name 'sonar-server' must match your SonarQube server config in Jenkins
        withSonarQubeEnv('sonar-server') {
          script {
            docker.image(MAVEN_IMAGE).inside {
              // sonar.host.url and sonar.login will be injected by withSonarQubeEnv
              sh 'mvn -B sonar:sonar -Dsonar.projectKey=${APP_NAME} -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONAR_AUTH_TOKEN'
            }
          }
        }
      }
    }

    stage('Wait for SonarQube Quality Gate') {
      steps {
        timeout(time: 2, unit: 'MINUTES') {
          // requires SonarQube plugin; aborts pipeline if quality gate fails
          waitForQualityGate abortPipeline: true
        }
      }
    }

    stage('Trivy - FS (scan source)') {
      steps {
        // fail the build if HIGH/CRITICAL vulnerabilities found; change severities as needed
        sh 'trivy fs --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed --no-progress .'
      }
    }

    stage('Create image tag') {
      steps {
        script {
          // short git sha + build number for traceable tags
          def gitShort = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
          env.IMAGE_TAG = "${gitShort}-${env.BUILD_NUMBER}"
          echo "IMAGE_TAG = ${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build Docker image') {
      steps {
        sh "docker build -t ${ECR_REPO}:${IMAGE_TAG} -f Dockerfile ."
      }
    }

    stage('Trivy - Image scan') {
      steps {
        // scan built image, fail on HIGH/CRITICAL; adjust flags as you prefer
        sh "trivy image --exit-code 1 --severity HIGH,CRITICAL ${ECR_REPO}:${IMAGE_TAG}"
      }
    }

    stage('Push to ECR') {
      steps {
        // aws credentials must be stored in Jenkins with id 'aws-creds'
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-creds',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          sh '''
            set -e
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            ECR_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

            # create repo if not exists (idempotent)
            aws ecr describe-repositories --repository-names ${ECR_REPO} --region ${AWS_REGION} \
              || aws ecr create-repository --repository-name ${ECR_REPO} --region ${AWS_REGION}

            # login, tag, push
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_URI}
            docker tag ${ECR_REPO}:${IMAGE_TAG} ${ECR_URI}/${ECR_REPO}:${IMAGE_TAG}
            docker push ${ECR_URI}/${ECR_REPO}:${IMAGE_TAG}
          '''
        }
      }
    }

    stage('Deploy (run container on this EC2)') {
      steps {
        // using same aws-creds so we can pull from ECR; the container runs locally on the Jenkins host
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding',
                          credentialsId: 'aws-creds',
                          accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                          secretKeyVariable: 'AWS_SECRET_ACCESS_KEY']]) {
          sh '''
            set -e
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            ECR_URI=${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
            IMAGE=${ECR_URI}/${ECR_REPO}:${IMAGE_TAG}

            # stop & remove old container (if running)
            docker rm -f ${APP_NAME} || true

            # pull and run the new image (exposes APP_PORT on host)
            docker pull ${IMAGE}
            docker run -d --name ${APP_NAME} -p ${APP_PORT}:8080 --restart unless-stopped ${IMAGE}
          '''
        }
      }
    }
  }

  post {
    always {
      echo "Cleaning workspace..."
      cleanWs()
    }
    success {
      echo "Pipeline succeeded — image tag: ${IMAGE_TAG}"
    }
    failure {
      echo "Pipeline failed. Check the Console Output for details."
    }
  }
}
