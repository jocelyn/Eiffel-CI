set ISE_C_COMPILER=msc
set ISE_EC_FLAGS=-full
set ISE_EIFFEL=C:\_dev\eiffel\70
set ISE_PLATFORM=win64
set PATH=%PATH%;%ISE_EIFFEL%\studio\spec\%ISE_PLATFORM%\bin
set PATH=%PATH%;%ISE_EIFFEL%\library\gobo\spec\%ISE_PLATFORM%\bin
set PATH=%PATH%;%ISE_EIFFEL%\tools\spec\%ISE_PLATFORM%\bin
set ISE_LIBRARY=%ISE_EIFFEL%

set EIFFEL_SRC=%CD%
set ISE_LIBRARY=%EIFFEL_SRC%

IF -%JENKINS_GEANT_PREPARE%- EQU -TRUE- espawn "geant prepare"

mkdir COMP
cd COMP
set ISE_EC_FLAGS=-batch -melt -full -project_path %CD%

echo Compiling ec batch
ecb -config %EIFFEL_SRC%\Eiffel\Ace\ec.ecf -target batch > ._compilation_ec_batch.log
IF %ERRORLEVEL% NEQ 0 exit 2
echo.

echo Compiling ec bench
ecb -config %EIFFEL_SRC%\Eiffel\Ace\ec.ecf -target bench  > ._compilation_ec_bench.log
IF %ERRORLEVEL% NEQ 0 exit 2
echo.

echo Compiling ec bench_unix
ecb -config %EIFFEL_SRC%\Eiffel\Ace\ec.ecf -target bench_unix  > ._compilation_ec_bench_unix.log
IF %ERRORLEVEL% NEQ 0 exit 2
echo.

echo Completed

