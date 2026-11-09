package com.sesori.app

import java.io.ByteArrayInputStream
import java.io.File
import java.nio.file.Files
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Before
import org.junit.Test

class DocumentPickerServiceTest {
    private lateinit var root: File

    @Before
    fun setUp() {
        root = File(Files.createTempDirectory("composer-picks-test").toFile(), "composer-picks")
    }

    @After
    fun tearDown() {
        root.parentFile?.deleteRecursively()
    }

    private fun document(name: String?, size: Long?, bytes: ByteArray) =
        PickedDocument(displayName = name, size = size, open = { ByteArrayInputStream(bytes) })

    @Test
    fun copiesEachDocumentUnderItsOwnName() {
        val copied = copyPickedDocuments(
            documents = listOf(
                document(name = "notes.txt", size = 5, bytes = "hello".toByteArray()),
                document(name = "notes.txt", size = 3, bytes = "bye".toByteArray()),
            ),
            root = root,
            maxBytes = 10,
        )

        assertEquals(0, copied.oversizedCount)
        assertEquals(listOf("notes.txt", "notes.txt"), copied.paths.map { File(it).name })
        assertEquals(listOf("hello", "bye"), copied.paths.map { File(it).readText() })
    }

    @Test
    fun neverOpensADocumentReportedOverTheLimit() {
        val tooLarge = PickedDocument(
            displayName = "video.mp4",
            size = 11,
            open = { throw AssertionError("an oversized document was opened") },
        )

        val copied = copyPickedDocuments(
            documents = listOf(tooLarge, document(name = "a.txt", size = 1, bytes = "a".toByteArray())),
            root = root,
            maxBytes = 10,
        )

        assertEquals(1, copied.oversizedCount)
        assertEquals(listOf("a.txt"), copied.paths.map { File(it).name })
    }

    @Test
    fun dropsADocumentOfUnknownSizeOnceItPassesTheLimit() {
        val copied = copyPickedDocuments(
            documents = listOf(document(name = "stream.bin", size = null, bytes = ByteArray(11))),
            root = root,
            maxBytes = 10,
        )

        assertEquals(1, copied.oversizedCount)
        assertEquals(emptyList<String>(), copied.paths)
        assertFalse(File(root, "0/stream.bin").exists())
    }

    @Test
    fun clearsThePreviousPicksCopies() {
        val earlier = copyPickedDocuments(
            documents = listOf(document(name = "old.txt", size = 1, bytes = "o".toByteArray())),
            root = root,
            maxBytes = 10,
        )

        copyPickedDocuments(documents = emptyList(), root = root, maxBytes = 10)

        assertFalse(File(earlier.paths.single()).exists())
    }

    @Test
    fun namesAFileByTheLastSegmentOfItsDisplayName() {
        assertEquals("report.pdf", safeFileName(displayName = "docs/report.pdf"))
        assertEquals("file", safeFileName(displayName = null))
        assertEquals("file", safeFileName(displayName = " "))
        assertEquals("file", safeFileName(displayName = ".."))
    }
}
