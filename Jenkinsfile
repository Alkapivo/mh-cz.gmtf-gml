pipeline {
  agent any

  options {
    timeout(time: 60, unit: 'MINUTES')
    buildDiscarder(logRotator(numToKeepStr: '14'))
  }

  stages {
    stage('Verify gmtf-gml') {
      steps {
        script {
          def buildJob = build(
            job: 'core-project/verify',
            propagate: true,
            wait: true,
            parameters: [
              string(name: 'GIT_REVISION', value: "main"),
              string(name: 'GMS_RUNTIME', value: "VM"),
              string(name: 'BUILD_OPTIONS', value: ""),
              string(
                name: 'OVERRIDE_DEPENDENCIES',
                value: """
                {
                  "gmtf": {
                    "revision": "${env.GIT_COMMIT}"
                  }
                }
                """.stripIndent()
              )
            ]
          )
        }
      }
    }
  }
}
