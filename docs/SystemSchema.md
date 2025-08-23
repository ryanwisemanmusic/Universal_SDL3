Brainstorming a new system


/custom-os/
    /custom-os/root

    /custom-os/home 

    /custom-os/usr/
        /custom-os/usr/lib/

        /custom-os/usr/bin/

        /custom-os/usr/sbin/

        /custom-os/usr/local/
            /custom-os/usr/local/lib/

            /custom-os/usr/local/bin/

            /custom-os/usr/local/sbin/

        /custom-os/usr/share/
    
    /custom-os/compiler/
        /custom-os/compiler/include

        /custom-os/compiler/lib

        /custom-os/compiler/bin/
            - clang-16
            - clang++-16
            - llvm-config-16

    /custom-os/glibc/
        /custom-os/glibc/include

        /custom-os/glibc/lib/

        /custom-os/glibc/bin

        /custom-os/glibc/sbin

    /custom-os/bin/ 

    /custom-os/sbin/ 

    /custom-os/tmp/ 

    /custom-os/var/

    /custom-os/etc/ 
        /custom-os/etc/environment

        /custom-os/etc/profile.d
            - compiler.sh
            - glibc.sh


/PROJ_DIR/
    /PROJ_DIR/setup-scripts/
        - binlib_validator.sh           -> Transfers to /usr/local/bin
        - cflag_audit.sh                -> Transfers to /usr/local/bin
        - check_llvm15.sh               -> Transfers to /usr/local/bin
        - check-filesystem.sh           -> Transfers to /usr/local/bin
        - conflict_trigger.sh           -> Transfers to /usr/local/bin
        - context_inspector.sh          -> Transfers to /usr/local/bin
        - create-filesystem.sh          -> Transfers to /usr/local/bin
        - dep_chain_visualizer.sh       -> Transfers to /usr/local/bin
        - dependency_checker.sh         -> Transfers to /usr/local/bin
        - env_tracer.sh                 -> Transfers to /usr/local/bin
        - failure_reconstructor.sh      -> Transfers to /usr/local/bin
        - file_diff_analyzer.sh         -> Transfers to /usr/local/bin
        - file_finder.sh                -> Transfers to /usr/local/bin
        - fop-wrapper.sh                -> Transfers to /usr/local/bin
        - invalid_cache_checker.sh      -> Transfers to /usr/local/bin
        - layer_bloat_analyzer.sh       -> Transfers to /usr/local/bin
        - prov_tracer.sh                -> Transfers to /usr/local/bin
        - sgid_suid_scanner.sh          -> Transfers to /usr/local/bin
        - src_fetch.sh                  -> Transfers to /usr/local/bin
        - stage_went_wrong_tracer.sh    -> Transfers to /usr/local/bin
        - symbol_gen_check.sh           -> Transfers to /usr/local/bin
        - thread_optimizer.sh           -> Transfers to /usr/local/bin
        - version_matrix.sh             -> Transfers to /usr/local/bin


/usr/
    /usr/local/
        /usr/local/bin/
            - binlib_validator.sh
            - cflag_audit.sh
            - check_llvm15.sh
            - check-filesystem.sh
            - conflict_trigger.sh
            - context_inspector.sh
            - create-filesystem.sh
            - dep_chain_visualizer.sh
            - dependency_checker.sh
            - env_tracer.sh
            - failure_reconstructor.sh
            - file_diff_analyzer.sh
            - file_finder.sh
            - fop-wrapper.sh
            - invalid_cache_checker.sh
            - layer_bloat_analyzer.sh
            - prov_tracer.sh
            - sgid_suid_scanner.sh
            - src_fetch.sh
            - stage_went_wrong_tracer.sh
            - symbol_gen_check.sh
            - thread_optimizer.sh
            - version_matrix.sh
       

      

   
 

  

