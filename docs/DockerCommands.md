List of Docker Shell commands you can run:

# Version Matrix (Checking for versioning)
COPY setup-scripts/version_matrix.sh /usr/local/bin/version_matrix
RUN chmod +x /usr/local/bin/version_matrix && \
    version_matrix > /lilyspark/build_versions.txt && \
    cat /lilyspark/build_versions.txt

# Dependency checker (to make sure nothing is missing)
COPY setup-scripts/dependency_checker.sh /usr/local/bin/dependency_checker
RUN chmod +x /usr/local/bin/dependency_checker && \
    dependency_checker /lilyspark/compiler/bin /lilyspark/glibc/bin > /lilyspark/dependency_report.txt && \
    cat /lilyspark/dependency_report.txt
    
# For filefinder.sh (run when debugging)
COPY setup-scripts/filefinder.sh /usr/local/bin/filefinder
RUN chmod +x /usr/local/bin/filefinder

# For context-inspector.sh (run during build)
COPY setup-scripts/context-inspector.sh /usr/local/bin/context-inspector
RUN chmod +x /usr/local/bin/context-inspector && \
    context-inspector > /lilyspark/context_report.txt

# Filesystem diff setup
COPY setup-scripts/file_diff_analyzer.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/file_diff_analyzer.sh && \
    file_diff_analyzer.sh "filesystem-builder"

# Environment tracer setup
COPY setup-scripts/env_tracer.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/env_tracer.sh

# Permission checker setup
COPY setup-scripts/conflict_trigger.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/conflict_trigger.sh

# Provenance tracer setup
COPY setup-scripts/prov_tracer.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/prov_tracer.sh

# Source fetcher setup
COPY setup-scripts/src_fetch.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/src_fetch.sh

# Track current build stage
RUN echo "filesystem-builder" > /tmp/current_stage

# Log Docker operations
RUN echo "# $(date) - COPY/ADD operations" > /lilyspark/docker_operations.log
ONBUILD COPY --chown=root:root . /context
ONBUILD RUN find /context -type f | sed 's/^/COPY /' >> /lilyspark/docker_operations.log

# Install debug tools
COPY setup-scripts/stage_went_wrong_tracer.sh /usr/local/bin/
COPY setup-scripts/dep_chain_visualizer.sh /usr/local/bin/
COPY setup-scripts/failure_reconstructor.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Optimization tools setup
COPY setup-scripts/layer_bloat_analyzer.sh /usr/local/bin/
COPY setup-scripts/invalid_cache_checker.sh /usr/local/bin/
COPY setup-scripts/thread_optimizer.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/*.sh

# Example usage:
# RUN layer_bloat_analyzer.sh
# RUN invalid_cache_checker.sh /Dockerfile
# RUN thread_optimizer.sh /Dockerfile

