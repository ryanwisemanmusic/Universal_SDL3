// Simple FOP test that won't crash CMake
public class check_fop {
    public static void main(String[] args) {
        try {
            Class<?> fopClass = Class.forName("org.apache.fop.cli.Main");
            java.lang.reflect.Method mainMethod = fopClass.getMethod("main", String[].class);
            String[] versionArgs = {"-version"};
            mainMethod.invoke(null, (Object) versionArgs);
        } catch (Exception e) {
            System.err.println("FOP test error: " + e.getMessage());
            System.exit(1);
        }
    }
}