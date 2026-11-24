param(
    [string]$PowerToysDir = "",
    [string]$ProjectDir = $PSScriptRoot,
    [switch]$StageOnly,
    [switch]$NoRestart
)

# Tự động tìm thư mục cài PowerToys (bản cài cho người dùng hoặc cho toàn máy)
if ([string]::IsNullOrEmpty($PowerToysDir)) {
    foreach ($candidate in @("$env:LOCALAPPDATA\PowerToys", "$env:ProgramFiles\PowerToys")) {
        if (Test-Path (Join-Path $candidate "PowerToys.exe")) { $PowerToysDir = $candidate; break }
    }
}
if ([string]::IsNullOrEmpty($PowerToysDir)) {
    throw "Không tìm thấy PowerToys. Hãy chỉ định thư mục cài đặt bằng tham số -PowerToysDir."
}

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$transPath = Join-Path $ProjectDir "translations.json"
$backupDir = Join-Path $ProjectDir "backup"
$stagedDir = Join-Path $ProjectDir "staged_pri"

if (-not (Test-Path $transPath)) {
    throw "Không tìm thấy tệp từ điển bản dịch: $transPath"
}
if (-not (Test-Path $PowerToysDir)) {
    throw "Không tìm thấy thư mục cài đặt PowerToys: $PowerToysDir"
}

Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

public class PowerToysViPatcher
{
    public class TocEntry
    {
        public int Index;
        public byte[] RawId;
        public string Id;
        public ushort Qualifier;
        public ushort Flags1;
        public uint Flags2;
        public uint Offset;
        public uint Length;
        public byte[] RawSectionBytes;
    }

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool SetDllDirectory(string lpPathName);

    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern IntPtr LoadLibrary(string lpFileName);

    [DllImport("MRM.dll", CharSet = CharSet.Unicode)]
    static extern int MrmCreateResourceManager(string priFileName, out IntPtr resourceManager);

    [DllImport("MRM.dll")]
    static extern void MrmDestroyResourceManager(IntPtr mgr);

    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint dwThreadId);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern bool GetUserObjectInformation(IntPtr hObj, int nIndex, StringBuilder pvInfo, int nLength, out int lpnLengthNeeded);

    public static bool IsInteractiveDefaultDesktop()
    {
        var sb = new StringBuilder(256); int need;
        GetUserObjectInformation(GetThreadDesktop(GetCurrentThreadId()), 2, sb, 512, out need);
        return sb.ToString().Equals("Default", StringComparison.OrdinalIgnoreCase);
    }

    private static bool mrmLoaded = false;

    public static void InitMrm(string mrmDllPath)
    {
        if (mrmLoaded) return;
        SetDllDirectory(Path.GetDirectoryName(mrmDllPath));
        IntPtr h = LoadLibrary(mrmDllPath);
        if (h == IntPtr.Zero) throw new Exception("Cannot load MRM.dll: Win32 error " + Marshal.GetLastWin32Error());
        mrmLoaded = true;
    }

    public static bool VerifyPriWithMrm(string priPath)
    {
        IntPtr mgr;
        int hr = MrmCreateResourceManager(priPath, out mgr);
        if (hr == 0 && mgr != IntPtr.Zero)
        {
            MrmDestroyResourceManager(mgr);
            return true;
        }
        return false;
    }

    public static Dictionary<string, string> ParseJsonStringDict(string json)
    {
        var d = new Dictionary<string, string>(StringComparer.Ordinal);
        int i = 0, n = json.Length;
        Action skipWs = () => { while (i < n && char.IsWhiteSpace(json[i])) i++; };
        Func<string> readStr = () => {
            skipWs();
            if (i >= n || json[i] != '"') throw new Exception("Expected '\"' at " + i);
            i++;
            var sb = new StringBuilder();
            while (i < n)
            {
                char c = json[i++];
                if (c == '"') return sb.ToString();
                if (c == '\\')
                {
                    char e = json[i++];
                    switch (e)
                    {
                        case '"': sb.Append('"'); break;
                        case '\\': sb.Append('\\'); break;
                        case '/': sb.Append('/'); break;
                        case 'b': sb.Append('\b'); break;
                        case 'f': sb.Append('\f'); break;
                        case 'n': sb.Append('\n'); break;
                        case 'r': sb.Append('\r'); break;
                        case 't': sb.Append('\t'); break;
                        case 'u':
                            sb.Append((char)Convert.ToInt32(json.Substring(i, 4), 16));
                            i += 4;
                            break;
                        default: sb.Append(e); break;
                    }
                }
                else sb.Append(c);
            }
            throw new Exception("Unterminated JSON string");
        };
        skipWs();
        if (i < n && json[i] == '{') i++;
        while (true)
        {
            skipWs();
            if (i >= n || json[i] == '}') break;
            string k = readStr();
            skipWs();
            if (i < n && json[i] == ':') i++;
            string v = readStr();
            d[k] = v;
            skipWs();
            if (i < n && json[i] == ',') i++;
        }
        return d;
    }

    public static int PatchPriFile(string inPath, string outPath, Dictionary<string, string> translations)
    {
        byte[] file = File.ReadAllBytes(inPath);
        if (file.Length < 48) return 0;

        uint totalSize, tocOffset, secStart, verUnk, hdrUnk2;
        ushort numSections, priFlags;
        var toc = new List<TocEntry>();

        using (var ms = new MemoryStream(file))
        using (var br = new BinaryReader(ms))
        {
            string magic = Encoding.ASCII.GetString(br.ReadBytes(8));
            if (magic != "mrm_pri2") return 0;
            verUnk = br.ReadUInt32();
            totalSize = br.ReadUInt32();
            tocOffset = br.ReadUInt32();
            secStart = br.ReadUInt32();
            numSections = br.ReadUInt16();
            priFlags = br.ReadUInt16();
            hdrUnk2 = br.ReadUInt32();

            ms.Position = tocOffset;
            for (int i = 0; i < numSections; i++)
            {
                byte[] rawId = br.ReadBytes(16);
                string id = Encoding.ASCII.GetString(rawId).TrimEnd('\0', ' ');
                ushort qual = br.ReadUInt16();
                ushort f1 = br.ReadUInt16();
                uint f2 = br.ReadUInt32();
                uint off = br.ReadUInt32();
                uint len = br.ReadUInt32();
                byte[] secBytes = new byte[len];
                Buffer.BlockCopy(file, (int)(secStart + off), secBytes, 0, (int)len);
                toc.Add(new TocEntry
                {
                    Index = i, RawId = rawId, Id = id,
                    Qualifier = qual, Flags1 = f1, Flags2 = f2,
                    Offset = off, Length = len, RawSectionBytes = secBytes
                });
            }
        }

        var decnToc = toc.FirstOrDefault(t => t.Id == "[mrm_decn_info]");
        var rmapToc = toc.FirstOrDefault(t => t.Id == "[mrm_res_map2_]");
        if (decnToc == null || rmapToc == null) return 0;

        var qualifierSets = new List<List<Tuple<ushort, string>>>();
        var decisions = new List<List<int>>();
        using (var ms = new MemoryStream(decnToc.RawSectionBytes))
        using (var br = new BinaryReader(ms))
        {
            ms.Position = 32;
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
        foreach (var t in toc.Where(x => x.Id == "[mrm_dataitem]"))
        {
            using (var ms = new MemoryStream(t.RawSectionBytes))
            using (var br = new BinaryReader(ms))
            {
                ms.Position = 32;
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
                dataSecs[t.Index] = items;
            }
        }
        if (dataSecs.Count == 0) return 0;

        byte[] rmapBytes = (byte[])rmapToc.RawSectionBytes.Clone();
        long candsStartInRmap;
        uint[] vt;
        int utf8VtIdx = -1, utf16VtIdx = -1;
        var i2g = new List<Tuple<uint, uint>>();
        var grp = new List<Tuple<uint, uint>>();
        var iis = new List<Tuple<uint, uint>>();
        var cands = new List<Tuple<byte, byte, ushort, uint>>();
        byte[] inlineData;

        using (var ms = new MemoryStream(rmapBytes))
        using (var br = new BinaryReader(ms))
        {
            ms.Position = 32;
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
            if (numC == 0) return 0;
            ms.Position += envRefLen + schemaRefLen;
            vt = new uint[numVT];
            for (int i = 0; i < numVT; i++) {
                br.ReadUInt32();
                vt[i] = br.ReadUInt32();
                if (vt[i] == 4) utf8VtIdx = i;
                if (vt[i] == 0) utf16VtIdx = i;
            }
            for (int i = 0; i < numI2G; i++) i2g.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
            for (int i = 0; i < numG; i++) grp.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
            for (int i = 0; i < numII; i++) iis.Add(Tuple.Create((uint)br.ReadUInt16(), (uint)br.ReadUInt16()));
            if (largeLen > 0) {
                uint l1 = br.ReadUInt32(); uint l2 = br.ReadUInt32(); uint l3 = br.ReadUInt32();
                for (uint i = 0; i < l1; i++) i2g.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
                for (uint i = 0; i < l2; i++) grp.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
                for (uint i = 0; i < l3; i++) iis.Add(Tuple.Create(br.ReadUInt32(), br.ReadUInt32()));
            }
            candsStartInRmap = ms.Position;
            for (uint i = 0; i < numC; i++) {
                byte st = br.ReadByte();
                byte v = br.ReadByte();
                if (st == 1) { br.ReadUInt16(); ushort di = br.ReadUInt16(); ushort si = br.ReadUInt16(); cands.Add(Tuple.Create(st, v, si, (uint)di)); }
                else { ushort len = br.ReadUInt16(); uint off = br.ReadUInt32(); cands.Add(Tuple.Create(st, v, len, off)); }
            }
            inlineData = br.ReadBytes((int)dataLen);
        }

        if (utf8VtIdx < 0 && utf16VtIdx < 0) return 0;

        // Pick the dataitem section with the smallest item count so newIdx always stays well under 65535
        int targetSecIdx = dataSecs.OrderBy(kv => kv.Value.Count).First().Key;
        var targetItems = dataSecs[targetSecIdx];
        var viStringIndexCache = new Dictionary<string, ushort>(StringComparer.Ordinal);
        bool useUtf8 = (utf8VtIdx >= 0);
        byte targetVtByte = (byte)(useUtf8 ? utf8VtIdx : utf16VtIdx);

        int patchedCount = 0;
        foreach (var itg in i2g)
        {
            if ((int)itg.Item2 >= grp.Count) continue;
            var g = grp[(int)itg.Item2];
            for (uint k = 0; k < g.Item1; k++)
            {
                var ii = iis[(int)(g.Item2 + k)];
                if ((int)ii.Item1 >= decisions.Count) continue;
                var dec = decisions[(int)ii.Item1];
                for (int c = 0; c < dec.Count; c++)
                {
                    var qs = qualifierSets[dec[c]];
                    var lang = string.Join(",", qs.Where(q => q.Item1 == 0).Select(q => q.Item2));
                    if (lang.Equals("EN-US", StringComparison.OrdinalIgnoreCase) || lang.Equals("EN", StringComparison.OrdinalIgnoreCase))
                    {
                        int candIdx = (int)(ii.Item2 + c);
                        if (candIdx >= cands.Count) continue;
                        var cr = cands[candIdx];
                        uint vtype = vt[cr.Item2];
                        if (vtype == 0 || vtype == 3 || vtype == 4)
                        {
                            byte[] raw = (cr.Item1 == 1)
                                ? dataSecs[cr.Item3][(int)cr.Item4]
                                : inlineData.Skip((int)cr.Item4).Take(cr.Item3).ToArray();
                            string orig = (vtype == 0)
                                ? Encoding.Unicode.GetString(raw).TrimEnd('\0')
                                : Encoding.UTF8.GetString(raw).TrimEnd('\0');
                            string translated;
                            if (translations.TryGetValue(orig, out translated) && !string.IsNullOrEmpty(translated) && translated != orig)
                            {
                                ushort newIdx;
                                if (!viStringIndexCache.TryGetValue(translated, out newIdx))
                                {
                                    if (targetItems.Count >= 65530) throw new Exception("DataItem section full!");
                                    byte[] enc = useUtf8
                                        ? Encoding.UTF8.GetBytes(translated + "\0")
                                        : Encoding.Unicode.GetBytes(translated + "\0");
                                    newIdx = (ushort)targetItems.Count;
                                    targetItems.Add(enc);
                                    viStringIndexCache[translated] = newIdx;
                                }
                                long cOff = candsStartInRmap + candIdx * 8L;
                                rmapBytes[cOff + 0] = 0x01;
                                rmapBytes[cOff + 1] = targetVtByte;
                                rmapBytes[cOff + 2] = 0x00;
                                rmapBytes[cOff + 3] = 0x00;
                                rmapBytes[cOff + 4] = (byte)(newIdx & 0xFF);
                                rmapBytes[cOff + 5] = (byte)((newIdx >> 8) & 0xFF);
                                rmapBytes[cOff + 6] = (byte)(targetSecIdx & 0xFF);
                                rmapBytes[cOff + 7] = (byte)((targetSecIdx >> 8) & 0xFF);
                                patchedCount++;
                            }
                        }
                    }
                }
            }
        }

        if (patchedCount == 0) return 0;

        rmapToc.RawSectionBytes = rmapBytes;

        var targetToc = toc[targetSecIdx];
        using (var dms = new MemoryStream())
        using (var dbw = new BinaryWriter(dms))
        {
            var offsets = new List<uint>();
            using (var blobMs = new MemoryStream())
            {
                foreach (var item in targetItems)
                {
                    while ((blobMs.Position % 4) != 0) blobMs.WriteByte(0);
                    offsets.Add((uint)blobMs.Position);
                    blobMs.Write(item, 0, item.Length);
                }
                while ((blobMs.Position % 8) != 0) blobMs.WriteByte(0);
                byte[] blob = blobMs.ToArray();

                int payloadLen = 12 + targetItems.Count * 8 + blob.Length;
                int rawTotal = 32 + payloadLen + 8;
                int padEnd = (8 - (rawTotal % 8)) % 8;
                uint newSecLen = (uint)(rawTotal + padEnd);

                byte[] secHdr = new byte[32];
                Buffer.BlockCopy(targetToc.RawSectionBytes, 0, secHdr, 0, 32);
                Buffer.BlockCopy(BitConverter.GetBytes(newSecLen), 0, secHdr, 24, 4);
                dbw.Write(secHdr);

                dbw.Write((uint)0);
                dbw.Write((ushort)0);
                dbw.Write((ushort)targetItems.Count);
                dbw.Write((uint)(blob.Length + padEnd));

                for (int i = 0; i < targetItems.Count; i++)
                {
                    dbw.Write(offsets[i]);
                    dbw.Write((uint)targetItems[i].Length);
                }
                dbw.Write(blob);
                for (int i = 0; i < padEnd; i++) dbw.Write((byte)0);

                dbw.Write((uint)0xDEF5FADE);
                dbw.Write(newSecLen);
            }
            targetToc.RawSectionBytes = dms.ToArray();
            targetToc.Length = (uint)targetToc.RawSectionBytes.Length;
        }

        uint curOff = 0;
        for (int i = 0; i < toc.Count; i++)
        {
            toc[i].Offset = curOff;
            toc[i].Length = (uint)toc[i].RawSectionBytes.Length;
            curOff += toc[i].Length;
        }

        uint newTotalSize = secStart + curOff + 16;

        Directory.CreateDirectory(Path.GetDirectoryName(outPath));
        using (var oms = new MemoryStream())
        using (var obw = new BinaryWriter(oms))
        {
            obw.Write(Encoding.ASCII.GetBytes("mrm_pri2"));
            obw.Write(verUnk);
            obw.Write(newTotalSize);
            obw.Write(tocOffset);
            obw.Write(secStart);
            obw.Write(numSections);
            obw.Write(priFlags);
            obw.Write(hdrUnk2);

            foreach (var t in toc)
            {
                obw.Write(t.RawId);
                obw.Write(t.Qualifier);
                obw.Write(t.Flags1);
                obw.Write(t.Flags2);
                obw.Write(t.Offset);
                obw.Write(t.Length);
            }

            while (oms.Position < secStart) obw.Write((byte)0);
            foreach (var t in toc) obw.Write(t.RawSectionBytes);

            obw.Write((uint)0xDEFFFADE);
            obw.Write(newTotalSize);
            obw.Write(Encoding.ASCII.GetBytes("mrm_pri2"));

            File.WriteAllBytes(outPath, oms.ToArray());
        }

        return patchedCount;
    }
}
"@

# Load translations dictionary (case-sensitive JSON parser, works in both PS 5.1 and PS 7)
Write-Host "Đang nạp từ điển tiếng Việt..." -ForegroundColor Cyan
$dict = [PowerToysViPatcher]::ParseJsonStringDict([System.IO.File]::ReadAllText($transPath, [System.Text.Encoding]::UTF8))
Write-Host "Đã nạp $($dict.Count) mục dịch." -ForegroundColor Green

# Init MRM.dll for verification
$mrmPath = Join-Path $PowerToysDir "WinUI3Apps\MRM.dll"
[PowerToysViPatcher]::InitMrm($mrmPath)

# Find all PowerToys PRI files (prefer original backup as source if backup already exists!)
$priFiles = Get-ChildItem $PowerToysDir -Recurse -Filter "*.pri" | Where-Object {
    $_.Name -notlike "Microsoft.UI*" -and
    $_.Name -notlike "Microsoft.Windows*" -and
    $_.Name -notlike "Microsoft.Toolkit*"
}

if (Test-Path $stagedDir) { Remove-Item $stagedDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stagedDir | Out-Null

$stagedList = @()
$totalPatched = 0

foreach ($f in $priFiles) {
    $rel = $f.FullName.Substring($PowerToysDir.Length).TrimStart('\')
    $backupFile = Join-Path $backupDir $rel
    # Always patch from clean original backup if present, otherwise from installed file
    $srcFile = if (Test-Path $backupFile) { $backupFile } else { $f.FullName }
    $dstStaged = Join-Path $stagedDir $rel
    try {
        $cnt = [PowerToysViPatcher]::PatchPriFile($srcFile, $dstStaged, $dict)
        if ($cnt -gt 0) {
            if (-not [PowerToysViPatcher]::VerifyPriWithMrm($dstStaged)) {
                throw "MRM.dll kiểm thử thất bại cho tệp $rel!"
            }
            $totalPatched += $cnt
            $stagedList += [PSCustomObject]@{ Rel = $rel; SrcOrig = $f.FullName; Backup = $backupFile; Staged = $dstStaged; Count = $cnt }
            Write-Host ("  [OK] {0,-58} ({1,4} chuỗi, MRM verified)" -f $rel, $cnt) -ForegroundColor Green
        }
    } catch {
        Write-Warning "Bỏ qua $rel : $($_.Exception.Message)"
    }
}

Write-Host "`nTổng cộng đã vá & xác minh bằng MRM.dll: $($stagedList.Count) tệp PRI ($totalPatched chuỗi)." -ForegroundColor Cyan

if ($StageOnly) {
    Write-Host "Chế độ -StageOnly: chỉ tạo và kiểm thử tệp tại $stagedDir, chưa ghi đè vào PowerToys." -ForegroundColor Yellow
    exit 0
}

# Stop PowerToys processes cleanly before replacing files
Write-Host "`nĐang tạm dừng các tiến trình PowerToys..." -ForegroundColor Cyan
$ptProcs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $_.Name -like "PowerToys*" -or ($_.Path -and $_.Path.StartsWith($PowerToysDir, [StringComparison]::OrdinalIgnoreCase))
}
foreach ($p in $ptProcs) {
    try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
}
Start-Sleep -Milliseconds 1500

# Create backup (only if original backup doesn't exist yet!) and copy staged files
$applied = 0
foreach ($item in $stagedList) {
    if (-not (Test-Path $item.Backup)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $item.Backup) | Out-Null
        Copy-Item -Path $item.SrcOrig -Destination $item.Backup -Force
    }
    Copy-Item -Path $item.Staged -Destination $item.SrcOrig -Force
    $applied++
}

Write-Host "Đã sao lưu bản gốc tại: $backupDir" -ForegroundColor Green
Write-Host "Đã áp dụng gói Việt hóa cho $applied tệp PRI thành công!" -ForegroundColor Green

if (-not $NoRestart) {
    if ([PowerToysViPatcher]::IsInteractiveDefaultDesktop()) {
        Write-Host "`nĐang khởi động lại PowerToys..." -ForegroundColor Cyan
        Start-Process -FilePath (Join-Path $PowerToysDir "PowerToys.exe")
        Start-Sleep -Seconds 2
        Write-Host "Hoàn tất! Hãy mở PowerToys Settings để xem giao diện Tiếng Việt." -ForegroundColor Green
    } else {
        Write-Host "`nHoàn tất! Hãy mở PowerToys từ Start Menu của Windows để xem giao diện Tiếng Việt." -ForegroundColor Green
    }
}
