pipeline {
    agent {
        dockerfile {
            image 'obolibrary/odkfull:v1.1.7'
            label 'zeppo'
            args '-u root:root'
        }
    }
     stages {
         stage('Build') {
             steps {
                    sh "whoami"
                    sh "env" 
                    sh "groups"
                    sh "pwd"
                    sh "ls -AlF"
                    sh "if [! -d phenoscape-data]; then git clone https://github.com/phenoscape/phenoscape-data.git; fi"
                    sh 'make all'
             }
         }
//          stage('Test') {
//              steps {
//                     sh 'make test'
//              }
//          }
//          stage('Deploy') {
//              steps {
//                  sh 'make publish'
//              }
//          }
     }

 }
