To run this project, there are a few valuable commands you ought to know.
We manage the execution of terminal commands by the means of make. CMake
and Docker is our backend related to libraries, while make allows us to
test the execution of code within certain desirable parameters. From
running the whole program to only a snippet, here are some valuable
commands for reference:

- Extreme Cache Busting:
docker builder prune -a --force
docker system prune -a --volumes --force

- Overall Build w/ no Log:
make clean-docker && make build-docker && make run-docker

    I highly recommend against this, because you have to compile every
    single library from scratch. And its the most common place for hangups.

- Overall Build w/ Log:
make clean-docker-log && make build-docker-log && make run-docker-log 

    You still are likely to run into the hangup issues, however, you
    are able to go through the program more thoroughly, since the compiler
    is likely to reject failures, while the log file can easily just move
    on to the next thing unless its a fatal borking problem.

- Build Everything In Stages + CMake Out:
make clean-docker && make build-base-deps-docker-log && make build-filesystem-base-deps-builder-docker-log && make build-filesystem-libs-build-builder-docker-log && make build-app-build-docker-log && make build-debug-docker-log && make build-runtime-docker-log && make run-docker && make dump-cmake-output


- Stage 1 Build w/ no Log:
make clean-base-deps-docker && make build-base-deps-docker 

- Stage 2 Build w/ no Log:
make clean-filesystem-base-deps-builder-docker && make build-filesystem-base-deps-builder-docker

- Stage 3 Build w/ no Log: 
make clean-filesystem-libs-build-builder-docker && make build-filesystem-libs-build-builder-docker

- Stage 4 Build w/ no Log:
make clean-app-build-docker && make build-app-build-docker

- Stage 5 Build w/ no Log:
make clean-debug-docker && make build-debug-docker

- Stage 6 Build w/ no Log:
make clean-runtime-docker && make build-runtime-docker

- Stage 1 Build w/ Log:
make clean-base-deps-docker-log && make build-base-deps-docker-log

- Stage 2 Build w/ Log:
make clean-filesystem-base-deps-builder-docker-log && make build-filesystem-base-deps-builder-docker-log

- Stage 3 Build w/ Log: 
make clean-filesystem-libs-build-builder-docker-log && make build-filesystem-libs-build-builder-docker-log

- Stage 4 Build w/ Log:
make clean-app-build-docker-log && make build-app-build-docker-log

- Stage 5 Build w/ Log:
make clean-debug-docker-log && make build-debug-docker-log

- Stage 6 Build w/ Log:
make clean-runtime-docker-log && make build-runtime-docker-log

    For updating code, it is better that we have a procedure of rollback
    based on the layer we want to work under. Because compile times with
    an OS of so many required dependencies, we want to use this rollback.

- Stage 5 Rollback:
make clean-runtime-docker && make clean-debug-docker

- Stage 5 Rollback + Build:
make clean-runtime-docker && make clean-debug-docker && make build-debug-docker

- Stage 4 Rollback:
make clean-runtime-docker && make clean-debug-docker && 
make clean-app-build-docker

- Stage 4 Rollback + Build:
make clean-runtime-docker && make clean-debug-docker && 
make clean-app-build-docker && make build-app-build-docker

- Stage 3 Rollback:
make clean-runtime-docker && make clean-debug-docker && 
make clean-app-build-docker && make clean-filesystem-libs-build-builder-docker

- Stage 3 Rollback + Build:
make clean-runtime-docker && make clean-debug-docker && 
make clean-app-build-docker && make clean-filesystem-libs-build-builder-docker &&
make build-filesystem-libs-build-builder-docker

- Start Rollback:
make clean-runtime-docker && make clean-debug-docker && 
make clean-app-build-docker && make clean-filesystem-libs-build-builder-docker &&
make clean-filesystem-base-deps-builder-docker && make clean-base-deps-docker

- Stage 5 Rollback w/ Log:
make clean-runtime-docker-log && make clean-debug-docker-log

- Stage 5 Rollback + Build w/ Log:
make clean-runtime-docker-log && make clean-debug-docker-log && make build-debug-docker-log

- Stage 4 Rollback w/ Log:
make clean-runtime-docker-log && make clean-debug-docker-log && 
make clean-app-build-docker-log

- Stage 4 Rollback + Build w/ Log:
make clean-runtime-docker-log && make clean-debug-docker-log && 
make clean-app-build-docker-log && make build-app-build-docker-log

- Stage 3 Rollback w/ Log:
make clean-runtime-docker-log && make clean-debug-docker-log && 
make clean-app-build-docker-log && make clean-filesystem-libs-build-builder-docker-log

- Stage 3 Rollback + Build w/ Log:
make clean-runtime-docker-log && make clean-debug-docker-log && 
make clean-app-build-docker-log && make clean-filesystem-libs-build-builder-docker-log &&
make build-filesystem-libs-build-builder-docker-log

- Start Rollback:
make clean-runtime-docker-log && make clean-debug-docker-log && 
make clean-app-build-docker-log && make clean-filesystem-libs-build-builder-docker-log &&
make clean-filesystem-base-deps-builder-docker-log && make clean-base-deps-docker-log
