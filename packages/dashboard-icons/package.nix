{
  lib,
  fetchFromGitHub,
  maintainers,
}:

fetchFromGitHub {
  pname = "dashboard-icons";
  version = "unstable";
  owner = "homarr-labs";
  repo = "dashboard-icons";
  rev = "159b55c82cc3874d7239d12455cc331cd161f680";
  hash = "sha256-LKZzGIdowY4ePo2nw5MSO3oXXLgL0vdt9RRhIy4+FlM=";

  meta = {
    description = "Your definitive source for dashboard icons";
    homepage = "https://dashboardicons.com";
    license = lib.licenses.asl20;
    maintainers = [ maintainers.awildleon ];
    platforms = lib.platforms.all;
  };
}
