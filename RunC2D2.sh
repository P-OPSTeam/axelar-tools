# Get version of C2D2
C2D2_VERSION=$(curl -s https://raw.githubusercontent.com/axelarnetwork/axelarate-community/main/TESTNET%20RELEASE.md | grep c2d2 | cut -d \` -f 4)

cd ~/axelarate-community

# Run c2d2
./c2d2/c2d2cli.sh --version $C2D2_VERSION

# Generate address
c2d2cli keys add c2d2

# Show the address
c2d2cli keys show c2d2 -a