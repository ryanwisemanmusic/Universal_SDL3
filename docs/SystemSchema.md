Brainstorming a new system


/lilyspark/
    /lilyspark/root


    /lilyspark/home 


    /lilyspark/usr/
        /lilyspark/usr/lib/
            - gcc library
            - g++ library
            - musl-dev library
            - binutils library
            - make library

        /lilyspark/usr/bin/
            - bash                      (binary)
            - cmake                     (binary)
            - coreutils                 (binary)
            - file                      (binary)
            - findutils                 (binary)
            - meson                     (binary)
            - ninja                     (binary)
            - wget                      (binary)
        
        /lilyspark/usr/debug/
            lilyspark/usr/debug/bin/
                - file                  (binary)
                - tree                  (binary)
        /lilyspark/usr/include
            - linux-headers

        /lilyspark/usr/sbin/

        /lilyspark/usr/local/
            /lilyspark/usr/local/lib/

            /lilyspark/usr/local/bin/

            /lilyspark/usr/local/sbin/

        /lilyspark/usr/share/
    

    /lilyspark/compiler/
        /lilyspark/compiler/include
            - llvm16-dev headers

        /lilyspark/compiler/lib
            - llvm16 libraries

        /lilyspark/compiler/bin/
            - clang-16
            - clang++-16
            - llvm-config-16


    /lilyspark/dist


    /lilyspark/glibc/
        /lilyspark/glibc/include
            -glibc-dev headers

        /lilyspark/glibc/lib/
            - glibc runtime components

        /lilyspark/glibc/bin
            - glibc bin tools

        /lilyspark/glibc/sbin
            - glibc bin tools


    /lilyspark/bin/ 


    /lilyspark/sbin/ 


    /lilyspark/tmp/ 


    /lilyspark/var/


    /lilyspark/etc/ 
        /lilyspark/etc/environment

        /lilyspark/etc/profile.d
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
       

      

   
 

  

