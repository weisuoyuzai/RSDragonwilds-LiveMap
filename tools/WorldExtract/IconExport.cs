// 离线导出图标: 从游戏资源解码贴图, 保持长宽比缩放后居中放进 size x size 的透明画布, 存成 PNG
using CUE4Parse.FileProvider;
using CUE4Parse.UE4.Assets.Exports.Texture;
using CUE4Parse_Conversion.Textures;
using SkiaSharp;

public static class IconExport
{
    // names: 贴图名 -> 资源路径 (/Game/...X.X)
    public static void Run(IFileProvider provider, Dictionary<string, string> names, string outDir, int size)
    {
        Directory.CreateDirectory(outDir);
        // 部分贴图格式要用 Detex 原生库解码, DLL 内嵌在 CUE4Parse-Conversion 里, 释放到临时目录后加载
        var detex = Path.Combine(Path.GetTempPath(), "LiveMap_Detex.dll");
        if (CUE4Parse_Conversion.Textures.BC.DetexHelper.LoadDll(detex))
            CUE4Parse_Conversion.Textures.BC.DetexHelper.Initialize(detex);
        int ok = 0, fail = 0;
        foreach (var (name, path) in names)
        {
            try
            {
                var tex = provider.LoadPackageObject<UTexture2D>(path);
                var decoded = tex.Decode(Math.Max(size * 2, 128)) ?? tex.Decode();
                if (decoded == null) throw new Exception("decode failed");
                using var src = decoded.ToSkBitmap();
                using var dst = new SKBitmap(new SKImageInfo(size, size, SKColorType.Rgba8888, SKAlphaType.Premul));
                using (var canvas = new SKCanvas(dst))
                {
                    canvas.Clear(SKColors.Transparent);
                    float k = (float)size / Math.Max(src.Width, src.Height);
                    float w = src.Width * k, h = src.Height * k;
                    using var paint = new SKPaint { FilterQuality = SKFilterQuality.High, IsAntialias = true };
                    canvas.DrawBitmap(src, new SKRect((size - w) / 2, (size - h) / 2, (size + w) / 2, (size + h) / 2), paint);
                }
                using var data = dst.Encode(SKEncodedImageFormat.Png, 100);
                File.WriteAllBytes(Path.Combine(outDir, name + ".png"), data.ToArray());
                ok++;
            }
            catch (Exception e)
            {
                if (fail++ < 10) Console.Error.WriteLine($"icon FAIL {name}: {e.Message}");
            }
        }
        Console.Error.WriteLine($"icons ok={ok} failed={fail}");
    }
}
