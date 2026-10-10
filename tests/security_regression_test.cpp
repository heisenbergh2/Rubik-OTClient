#include <gtest/gtest.h>
#include <framework/core/resourcemanager.h>
#include <framework/net/inputmessage.h>
#include <framework/stdext/uri.h>

TEST(HttpUri, SchemeDeterminesTlsIndependentlyOfPort)
{
    const auto secure = parseURI("HTTPS://example.com:8443/login.php");
    EXPECT_EQ(secure.protocol, "https");
    EXPECT_EQ(secure.port, "8443");
    EXPECT_EQ(secure.query, "/login.php");
    const auto plain = parseURI("http://example.com:443/login.php");
    EXPECT_EQ(plain.protocol, "http");
    EXPECT_EQ(plain.port, "443");
    EXPECT_EQ(parseURI("wss://example.com/socket").port, "443");
    EXPECT_EQ(parseURI("https://example.com").query, "/");
    EXPECT_EQ(parseURI("ftp://example.com/file").domain, "");
}

TEST(InputPreview, FullPacketsAndNegativeCountsAreSafe)
{
    InputMessage message;
    const std::string packet(1024, 'x');
    message.setBuffer(packet);
    message.setReadPos(message.getReadPos() - packet.size());
    const int readPosition = message.getReadPos();
    EXPECT_EQ(message.peekBytes(300).size(), 300);
    EXPECT_EQ(message.peekBytes(4096).size(), packet.size());
    EXPECT_TRUE(message.peekBytes(-1).empty());
    EXPECT_EQ(message.getReadPos(), readPosition);
}

TEST(ConfigArchive, RoundTripKeepsBinaryAndNestedFiles)
{
    const std::unordered_map<std::string, std::string> files{
        {"main.lua", "print('hello')"},
        {"nested/settings.json", "{\"enabled\":true}"},
        {"empty.txt", ""},
        {"binary.dat", std::string("a\0b", 3)}
    };
    const std::string archive = g_resources.createArchive(files);
    ASSERT_FALSE(archive.empty());
    EXPECT_EQ(g_resources.decompressArchive(archive), files);
}

TEST(ConfigArchive, UnsafePathsAndNormalizedDuplicatesAreRejected)
{
    for (const std::string& name : {"../escape.lua", "/absolute.lua", "a/../../x", "C:/x", "a/./x", "a/../x"}) {
        EXPECT_TRUE(g_resources.createArchive({{name, "code"}}).empty()) << name;
    }
    EXPECT_TRUE(g_resources.createArchive({{"a/b", "one"}, {"a\\b", "two"}}).empty());
}

TEST(ConfigArchive, TruncationAndChecksumMismatchDoNotExtract)
{
    const std::string archive = g_resources.createArchive({{"test.lua", "payload"}});
    ASSERT_FALSE(archive.empty());
    for (size_t size = 0; size < archive.size(); ++size) {
        // Start with PK so raw truncated data is never mistaken for a file path.
        if (size >= 2)
            EXPECT_TRUE(g_resources.decompressArchive(archive.substr(0, size)).empty());
    }
    std::string corrupt = archive;
    corrupt[30 + std::string("test.lua").size()] ^= 1;
    EXPECT_TRUE(g_resources.decompressArchive(corrupt).empty());
}

TEST(ConfigArchive, FileSizeAndEntryCountAreBounded)
{
    EXPECT_TRUE(g_resources.createArchive({{"big.lua", std::string(8 * 1024 * 1024 + 1, 'x')}}).empty());
    std::unordered_map<std::string, std::string> files;
    for (int i = 0; i < 1025; ++i)
        files.emplace(std::to_string(i) + ".lua", "");
    EXPECT_TRUE(g_resources.createArchive(files).empty());
}

TEST(ConfigArchive, ReadsDeflatedZipProducedByPython)
{
    // Independent fixture produced by Python zipfile with ZIP_DEFLATED.
    const unsigned char data[] = {
        0x50,0x4b,0x03,0x04,0x14,0,0,0,0x08,0,0xfc,0x83,0x4a,0x5d,0x86,0xa6,
        0x10,0x36,0x07,0,0,0,0x05,0,0,0,0x08,0,0,0,0x6d,0x61,0x69,0x6e,0x2e,
        0x6c,0x75,0x61,0xcb,0x48,0xcd,0xc9,0xc9,0x07,0,0x50,0x4b,0x01,0x02,
        0x14,0,0x14,0,0,0,0x08,0,0xfc,0x83,0x4a,0x5d,0x86,0xa6,0x10,0x36,
        0x07,0,0,0,0x05,0,0,0,0x08,0,0,0,0,0,0,0,0,0,0,0,0x80,0x01,0,0,0,0,
        0x6d,0x61,0x69,0x6e,0x2e,0x6c,0x75,0x61,0x50,0x4b,0x05,0x06,0,0,0,0,
        0x01,0,0x01,0,0x36,0,0,0,0x2d,0,0,0,0,0
    };
    const std::string archive(reinterpret_cast<const char*>(data), sizeof(data));
    const auto files = g_resources.decompressArchive(archive);
    ASSERT_EQ(files.size(), 1);
    EXPECT_EQ(files.at("main.lua"), "hello");

    // A corrupt ZIP32 offset must be rejected before offset arithmetic wraps.
    std::string invalid = archive;
    const size_t centralPosition = invalid.find("PK\x01\x02");
    ASSERT_NE(centralPosition, std::string::npos);
    for (size_t i = 0; i < 4; ++i)
        invalid[centralPosition + 42 + i] = static_cast<char>(0xFF);
    EXPECT_TRUE(g_resources.decompressArchive(invalid).empty());
}
