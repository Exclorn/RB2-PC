// Xbox / Xbox 360 game disc (XDVDFS) extractor, loaded by PowerShell with Add-Type so the setup
// needs no Python. Port of tools/xdvdfs.py with two additions: file names from the image are
// validated (a booby-trapped image cannot write outside the target folder) and files that run past
// the end of the image are reported as an incomplete dump instead of being silently zero-filled.
//
// Written in C# 5 on purpose: Windows PowerShell 5.1's Add-Type compiler is C# 5.

using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

public static class Xiso
{
    const int Sector = 2048;
    const int MaxTableBytes = 64 * 1024 * 1024;
    const int MaxDepth = 32;
    static readonly long[] Offsets = new long[] { 0L, 0x2080000L, 0xFD90000L, 0x18300000L };
    static readonly byte[] Magic = Encoding.ASCII.GetBytes("MICROSOFT*XBOX*MEDIA");

    class Entry
    {
        public string Rel;      // path relative to the root, using the OS separator
        public bool IsDir;
        public uint Start;      // sector, relative to the partition
        public uint Length;
    }

    public class Result
    {
        public int Files;
        public long Bytes;
    }

    static InvalidDataException Bad(string msg)
    {
        return new InvalidDataException(msg);
    }

    static bool FindPartition(FileStream f, out long baseOffset, out uint rootSector, out uint rootSize)
    {
        byte[] buf = new byte[28];
        foreach (long off in Offsets)
        {
            long pos = off + 32L * Sector;
            if (pos + buf.Length > f.Length) continue;
            f.Seek(pos, SeekOrigin.Begin);
            ReadExactly(f, buf, buf.Length);
            bool ok = true;
            for (int i = 0; i < Magic.Length; i++) if (buf[i] != Magic[i]) { ok = false; break; }
            if (!ok) continue;
            baseOffset = off;
            rootSector = BitConverter.ToUInt32(buf, 20);
            rootSize = BitConverter.ToUInt32(buf, 24);
            return true;
        }
        baseOffset = 0; rootSector = 0; rootSize = 0;
        return false;
    }

    static void ReadExactly(Stream s, byte[] buf, int count)
    {
        int got = 0;
        while (got < count)
        {
            int n = s.Read(buf, got, count - got);
            if (n <= 0) throw Bad("The disc image ended unexpectedly: it is incomplete or damaged.");
            got += n;
        }
    }

    static string CheckName(string name)
    {
        if (name.Length == 0 || name == "." || name == ".." ||
            name.IndexOfAny(new char[] { '/', '\\', ':', '*', '?', '"', '<', '>', '|', '\0' }) >= 0)
            throw Bad("The disc image contains an invalid file name, so it was not extracted.");
        for (int i = 0; i < name.Length; i++)
            if (name[i] < 32) throw Bad("The disc image contains an invalid file name, so it was not extracted.");
        return name;
    }

    static void Walk(FileStream f, long baseOffset, uint sector, uint size, string path, List<Entry> output, int depth)
    {
        if (size == 0) return;
        if (depth > MaxDepth) throw Bad("The disc image has an impossibly deep folder structure.");
        if (size > MaxTableBytes) throw Bad("The disc image has a corrupt directory table.");
        long start = baseOffset + (long)sector * Sector;
        if (start + size > f.Length) throw Bad("The disc image is incomplete: a folder listing lies past the end of the file.");
        f.Seek(start, SeekOrigin.Begin);
        byte[] table = new byte[size];
        ReadExactly(f, table, table.Length);
        HashSet<int> seen = new HashSet<int>();
        Node(f, baseOffset, table, 0, path, output, depth, seen);
    }

    static void Node(FileStream f, long baseOffset, byte[] table, int o, string path, List<Entry> output, int depth, HashSet<int> seen)
    {
        if (seen.Contains(o) || o + 14 > table.Length) return;
        seen.Add(o);
        int left = BitConverter.ToUInt16(table, o);
        int right = BitConverter.ToUInt16(table, o + 2);
        uint start = BitConverter.ToUInt32(table, o + 4);
        uint length = BitConverter.ToUInt32(table, o + 8);
        int attr = table[o + 12];
        int nameLen = table[o + 13];
        if (left == 0xFFFF && right == 0xFFFF && start == 0xFFFFFFFFu) return;
        if (o + 14 + nameLen > table.Length) throw Bad("The disc image has a corrupt directory table.");
        string name = CheckName(Encoding.GetEncoding(28591).GetString(table, o + 14, nameLen));

        if (left != 0) Node(f, baseOffset, table, left * 4, path, output, depth, seen);
        string rel = path.Length == 0 ? name : path + Path.DirectorySeparatorChar + name;
        if ((attr & 0x10) != 0)
        {
            Entry d = new Entry(); d.Rel = rel; d.IsDir = true; output.Add(d);
            Walk(f, baseOffset, start, length, rel, output, depth + 1);
        }
        else
        {
            Entry e = new Entry(); e.Rel = rel; e.IsDir = false; e.Start = start; e.Length = length; output.Add(e);
        }
        if (right != 0) Node(f, baseOffset, table, right * 4, path, output, depth, seen);
    }

    // progress(bytesDone, bytesTotal) may be null.
    public static Result Extract(string isoPath, string destination, Action<long, long> progress)
    {
        string destFull = Path.GetFullPath(destination);
        using (FileStream f = new FileStream(isoPath, FileMode.Open, FileAccess.Read, FileShare.Read, 1 << 20))
        {
            long baseOffset; uint rootSector, rootSize;
            if (!FindPartition(f, out baseOffset, out rootSector, out rootSize))
                throw Bad("This is not an Xbox / Xbox 360 game disc image (no game partition found).");

            List<Entry> entries = new List<Entry>();
            Walk(f, baseOffset, rootSector, rootSize, "", entries, 0);

            Result result = new Result();
            long total = 0;
            foreach (Entry e in entries)
            {
                if (e.IsDir) continue;
                total += e.Length;
                long begin = baseOffset + (long)e.Start * Sector;
                if (begin + e.Length > f.Length)
                    throw Bad("The disc image is incomplete: \"" + e.Rel + "\" runs past the end of the file. Make a fresh, complete dump of your disc.");
            }

            byte[] buf = new byte[4 << 20];
            long done = 0;
            foreach (Entry e in entries)
            {
                string target = Path.GetFullPath(Path.Combine(destFull, e.Rel));
                string rootWithSep = destFull.EndsWith(Path.DirectorySeparatorChar.ToString()) ? destFull : destFull + Path.DirectorySeparatorChar;
                if (!target.StartsWith(rootWithSep, StringComparison.OrdinalIgnoreCase))
                    throw Bad("The disc image tried to write outside the target folder, so it was not extracted.");
                if (e.IsDir) { Directory.CreateDirectory(target); continue; }
                Directory.CreateDirectory(Path.GetDirectoryName(target));
                f.Seek(baseOffset + (long)e.Start * Sector, SeekOrigin.Begin);
                using (FileStream o = new FileStream(target, FileMode.Create, FileAccess.Write, FileShare.None, 1 << 20))
                {
                    long left = e.Length;
                    while (left > 0)
                    {
                        int want = (int)Math.Min((long)buf.Length, left);
                        ReadExactly(f, buf, want);
                        o.Write(buf, 0, want);
                        left -= want;
                        done += want;
                        if (progress != null) progress(done, total);
                    }
                }
                result.Files++;
                result.Bytes += e.Length;
            }
            return result;
        }
    }
}
