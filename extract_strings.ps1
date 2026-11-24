$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Resources;
using System.Runtime.InteropServices;
using System.Text;

public class PriExtractor
{
    public class ExtractedItem
    {
        public string EnText;
        public string OfficialViText; // if VI-VN exists for the same resource item in PRI
        public List<string> Files = new List<string>();
    }

    public static void ExtractAllPri(string rootDir, string outDir)
    {
        Directory.CreateDirectory(outDir);
        var files = Directory.GetFiles(rootDir, "*.pri", SearchOption.AllDirectories)
            .Where(f => !Path.GetFileName(f).StartsWith("Microsoft.UI")
                     && !Path.GetFileName(f).StartsWith("Microsoft.Windows")
                     && !Path.GetFileName(f).StartsWith("Microsoft.Toolkit"))
            .OrderBy(f => f)
            .ToList();

        var map = new Dictionary<string, ExtractedItem>(StringComparer.Ordinal);
        int filesWithStrings = 0;

        foreach (var path in files)
        {
            try
            {
                string rel = path.Substring(rootDir.Length).TrimStart('\\');
                var pairs = ExtractEnAndViPairs(path);
                if (pairs.Count > 0) filesWithStrings++;
                foreach (var kv in pairs)
                {
                    ExtractedItem item;
                    if (!map.TryGetValue(kv.Key, out item))
                    {
                        item = new ExtractedItem { EnText = kv.Key, OfficialViText = kv.Value };
                        map[kv.Key] = item;
                    }
                    else if (string.IsNullOrEmpty(item.OfficialViText) && !string.IsNullOrEmpty(kv.Value))
                    {
                        item.OfficialViText = kv.Value;
                    }
                    if (!item.Files.Contains(rel)) item.Files.Add(rel);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("SKIP " + Path.GetFileName(path) + ": " + ex.Message);
            }
        }

        var officialVi = new SortedDictionary<string, string>(StringComparer.Ordinal);
        var needTranslate = new List<ExtractedItem>();

        foreach (var item in map.Values.OrderBy(x => x.Files[0]).ThenBy(x => x.EnText, StringComparer.Ordinal))
        {
            if (!string.IsNullOrEmpty(item.OfficialViText))
            {
                officialVi[item.EnText] = item.OfficialViText;
            }
            else
            {
                needTranslate.Add(item);
            }
        }

        Console.WriteLine(string.Format("PRI files with strings: {0}/{1}", filesWithStrings, files.Count));
        Console.WriteLine(string.Format("Total unique EN-US strings: {0}", map.Count));
        Console.WriteLine(string.Format("  Already have Microsoft official VI-VN: {0}", officialVi.Count));
        Console.WriteLine(string.Format("  Need Vietnamese translation: {0}", needTranslate.Count));

        // Write official_vi.json
        WriteJsonDict(Path.Combine(outDir, "official_vi.json"), officialVi);

        // Write need_translate.tsv (index \t files \t escaped_en) and need_translate.json
        var needDict = new Dictionary<string, string>(StringComparer.Ordinal);
        var tsvLines = new List<string>();
        int idx = 0;
        foreach (var item in needTranslate)
        {
            needDict[item.EnText] = "";
            string esc = item.EnText.Replace("\\", "\\\\").Replace("\r", "\\r").Replace("\n", "\\n").Replace("\t", "\\t");
            string fshort = string.Join(",", item.Files.Select(f => Path.GetFileNameWithoutExtension(f).Replace("PowerToys.", "")).Take(3));
            tsvLines.Add(idx + "\t" + fshort + "\t" + esc);
            idx++;
        }
        File.WriteAllLines(Path.Combine(outDir, "pri_to_translate.tsv"), tsvLines, new UTF8Encoding(false));
        WriteJsonDict(Path.Combine(outDir, "pri_to_translate.json"), needDict);
    }

    static string JsonEscape(string s)
    {
        var sb = new StringBuilder(s.Length + 8);
        sb.Append('"');
        foreach (char c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\b': sb.Append("\\b"); break;
                case '\f': sb.Append("\\f"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default:
                    if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c);
                    else sb.Append(c);
                    break;
            }
        }
        sb.Append('"');
        return sb.ToString();
    }

    public static void WriteJsonDict(string path, IDictionary<string, string> dict)
    {
        var sb = new StringBuilder();
        sb.AppendLine("{");
        int i = 0, n = dict.Count;
        foreach (var kv in dict)
        {
            sb.Append("  ").Append(JsonEscape(kv.Key)).Append(": ").Append(JsonEscape(kv.Value));
            if (++i < n) sb.Append(',');
            sb.AppendLine();
        }
        sb.AppendLine("}");
        File.WriteAllText(path, sb.ToString(), new UTF8Encoding(false));
    }

    public static Dictionary<string, string> ExtractEnAndViPairs(string path)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        byte[] file = File.ReadAllBytes(path);
        using (var ms = new MemoryStream(file))
        using (var br = new BinaryReader(ms))
        {
            if (file.Length < 48) return result;
            string magic = Encoding.ASCII.GetString(br.ReadBytes(8));
            if (magic != "mrm_pri2") return result;
            br.ReadUInt32();
            uint totalSize = br.ReadUInt32();
            uint tocOffset = br.ReadUInt32();
            uint secStart = br.ReadUInt32();
            ushort numSections = br.ReadUInt16();

            var toc = new List<Tuple<int, string, uint, uint>>();
            ms.Position = tocOffset;
            for (int i = 0; i < numSections; i++)
            {
                string id = Encoding.ASCII.GetString(br.ReadBytes(16)).TrimEnd('\0', ' ');
                br.ReadUInt64();
                uint off = br.ReadUInt32();
                uint len = br.ReadUInt32();
                toc.Add(Tuple.Create(i, id, off, len));
            }

            var decnToc = toc.FirstOrDefault(t => t.Item2 == "[mrm_decn_info]");
            var rmapToc = toc.FirstOrDefault(t => t.Item2 == "[mrm_res_map2_]");
            if (decnToc == null || rmapToc == null) return result;

            var qualifierSets = new List<List<Tuple<ushort, string>>>();
            var decisions = new List<List<int>>();
            {
                ms.Position = secStart + decnToc.Item3 + 32;
                ushort numDQ = br.ReadUInt16();
                ushort numQ = br.ReadUInt16();
                ushort numQS = br.ReadUInt16();
                ushort numD = br.ReadUInt16();
                ushort numIdx = br.ReadUInt16();
                ushort dataChars = br.ReadUInt16();

                var decMeta = new List<Tuple<ushort, ushort>>();
                for (int i = 0; i < numD; i++) decMeta.Add(Tuple.Create(br.ReadUInt16(), br.ReadUInt16()));
                var qsMeta = new List<Tuple<ushort, ushort>>();
                for (int i = 0; i < numQS; i++) qsMeta.Add(Tuple.Create(br.ReadUInt16(), br.ReadUInt16()));
                var qMeta = new List<ushort>();
                for (int i = 0; i < numQ; i++) { qMeta.Add(br.ReadUInt16()); br.ReadBytes(6); }
                var dqList = new List<Tuple<ushort, uint>>();
                for (int i = 0; i < numDQ; i++) { br.ReadUInt16(); ushort qt = br.ReadUInt16(); br.ReadUInt32(); dqList.Add(Tuple.Create(qt, br.ReadUInt32())); }
                var idxTable = new ushort[numIdx];
                for (int i = 0; i < numIdx; i++) idxTable[i] = br.ReadUInt16();
                byte[] strBytes = br.ReadBytes(dataChars * 2);

                Func<uint, string> readStr = (chOff) => {
                    int bOff = (int)(chOff * 2);
                    int end = bOff;
                    while (end + 1 < strBytes.Length && (strBytes[end] != 0 || strBytes[end + 1] != 0)) end += 2;
                    return Encoding.Unicode.GetString(strBytes, bOff, end - bOff);
                };

                var quals = new List<Tuple<ushort, string>>();
                for (int i = 0; i < numQ; i++) { var dq = dqList[qMeta[i]]; quals.Add(Tuple.Create(dq.Item1, readStr(dq.Item2))); }
                for (int i = 0; i < numQS; i++) {
                    var l = new List<Tuple<ushort, string>>();
                    for (int k = 0; k < qsMeta[i].Item2; k++) l.Add(quals[idxTable[qsMeta[i].Item1 + k]]);
                    qualifierSets.Add(l);
                }
                for (int i = 0; i < numD; i++) {
                    var l = new List<int>();
                    for (int k = 0; k < decMeta[i].Item2; k++) l.Add(idxTable[decMeta[i].Item1 + k]);
                    decisions.Add(l);
                }
            }

            var dataSecs = new Dictionary<int, List<byte[]>>();
            foreach (var t in toc.Where(x => x.Item2 == "[mrm_dataitem]"))
            {
                ms.Position = secStart + t.Item3 + 32;
                br.ReadUInt32();
                ushort nS = br.ReadUInt16();
                ushort nL = br.ReadUInt16();
                uint dSize = br.ReadUInt32();
                var spans = new List<Tuple<uint, uint>>();
                for (int i = 0; i < nS; i++) spans.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
                for (int i = 0; i < nL; i++) spans.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
                byte[] blob = br.ReadBytes((int)dSize);
                var items = new List<byte[]>();
                foreach (var sp in spans) { byte[] b = new byte[sp.Item2]; Buffer.BlockCopy(blob, (int)sp.Item1, b, 0, (int)sp.Item2); items.Add(b); }
                dataSecs[t.Item1] = items;
            }

            ms.Position = secStart + rmapToc.Item3 + 32;
            ushort envRefLen = br.ReadUInt16();
            ushort numEnvRefs = br.ReadUInt16();
            ushort schemaSec = br.ReadUInt16();
            ushort schemaRefLen = br.ReadUInt16();
            ushort decnSec = br.ReadUInt16();
            ushort numVT = br.ReadUInt16();
            ushort numI2G = br.ReadUInt16();
            ushort numG = br.ReadUInt16();
            uint numII = br.ReadUInt32();
            uint numC = br.ReadUInt32();
            uint dataLen = br.ReadUInt32();
            uint largeLen = br.ReadUInt32();
            if (numC == 0) return result;
            ms.Position += envRefLen + schemaRefLen;
            var vt = new uint[numVT];
            for (int i = 0; i < numVT; i++) { br.ReadUInt32(); vt[i] = br.ReadUInt32(); }
            var i2g = new List<Tuple<uint, uint>>();
            for (int i = 0; i < numI2G; i++) i2g.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
            var grp = new List<Tuple<uint, uint>>();
            for (int i = 0; i < numG; i++) grp.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
            var iis = new List<Tuple<uint, uint>>();
            for (int i = 0; i < numII; i++) iis.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
            if (largeLen > 0) {
                uint l1 = br.ReadUInt32(); uint l2 = br.ReadUInt32(); uint l3 = br.ReadUInt32();
                for (uint i = 0; i < l1; i++) i2g.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
                for (uint i = 0; i < l2; i++) grp.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
                for (uint i = 0; i < l3; i++) iis.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
            }
            var cands = new List<Tuple<byte, byte, ushort, uint>>();
            for (uint i = 0; i < numC; i++) {
                byte st = br.ReadByte();
                byte v = br.ReadByte();
                if (st == 1) { br.ReadUInt16(); ushort di = br.ReadUInt16(); ushort si = br.ReadUInt16(); cands.Add(Tuple.Create(st, v, si, (uint)di)); }
                else { ushort len = br.ReadUInt16(); uint off = br.ReadUInt32(); cands.Add(Tuple.Create(st, v, len, off)); }
            }
            byte[] inlineData = br.ReadBytes((int)dataLen);

            foreach (var itg in i2g) {
                if ((int)itg.Item2 >= grp.Count) continue;
                var g = grp[(int)itg.Item2];
                for (uint k = 0; k < g.Item1; k++) {
                    var ii = iis[(int)(g.Item2 + k)];
                    if ((int)ii.Item1 >= decisions.Count) continue;
                    var dec = decisions[(int)ii.Item1];
                    string enVal = null;
                    string viVal = null;
                    for (int c = 0; c < dec.Count; c++) {
                        var qs = qualifierSets[dec[c]];
                        var lang = string.Join(",", qs.Where(q => q.Item1 == 0).Select(q => q.Item2));
                        bool isEn = lang.Equals("EN-US", StringComparison.OrdinalIgnoreCase) || lang.Equals("EN", StringComparison.OrdinalIgnoreCase);
                        bool isVi = lang.Equals("VI-VN", StringComparison.OrdinalIgnoreCase) || lang.Equals("VI", StringComparison.OrdinalIgnoreCase);
                        if (!isEn && !isVi) continue;
                        int cIdx = (int)(ii.Item2 + c);
                        if (cIdx >= cands.Count) continue;
                        var cr = cands[cIdx];
                        uint vtype = vt[cr.Item2];
                        if (vtype == 0 || vtype == 3 || vtype == 4) {
                            byte[] raw = (cr.Item1 == 1) ? dataSecs[cr.Item3][(int)cr.Item4] : inlineData.Skip((int)cr.Item4).Take(cr.Item3).ToArray();
                            string s = (vtype == 0) ? Encoding.Unicode.GetString(raw).TrimEnd('\0') : Encoding.UTF8.GetString(raw).TrimEnd('\0');
                            if (isEn) enVal = s;
                            if (isVi) viVal = s;
                        }
                    }
                    if (enVal != null)
                    {
                        if (!result.ContainsKey(enVal) || (string.IsNullOrEmpty(result[enVal]) && !string.IsNullOrEmpty(viVal)))
                            result[enVal] = viVal;
                    }
                }
            }
        }
        return result;
    }

    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);
    [DllImport("kernel32.dll")] static extern bool FreeLibrary(IntPtr hModule);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)]
    static extern int LoadString(IntPtr hInstance, uint uID, StringBuilder lpBuffer, int nBufferMax);

    public static void DumpWin32Strings(string exePath)
    {
        IntPtr h = LoadLibraryEx(exePath, IntPtr.Zero, 0x00000002);
        if (h == IntPtr.Zero) return;
        Console.WriteLine("=== Win32 RT_STRING in " + Path.GetFileName(exePath) + " ===");
        var sb = new StringBuilder(1024);
        int found = 0;
        for (uint id = 1; id < 2000; id++)
        {
            int len = LoadString(h, id, sb, sb.Capacity);
            if (len > 0)
            {
                Console.WriteLine(string.Format("  [{0}] {1}", id, sb.ToString()));
                found++;
            }
        }
        Console.WriteLine("  Total found (id<2000): " + found);
        FreeLibrary(h);
    }
}
"@

$pt = "$env:LOCALAPPDATA\PowerToys"
$proj = $PSScriptRoot
[PriExtractor]::ExtractAllPri($pt, "$proj\extracted")
[PriExtractor]::DumpWin32Strings("$pt\PowerToys.exe")
