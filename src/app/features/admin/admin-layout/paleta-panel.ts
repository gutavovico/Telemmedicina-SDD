function canales(color: string): number[] {
  return [1, 3, 5].map(offset => parseInt(color.slice(offset, offset + 2), 16));
}

function luminancia(rgb: number[]): number {
  const [r, g, b] = rgb.map(valor => {
    const srgb = valor / 255;
    return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function textoSobre(color: string): string {
  return luminancia(canales(color)) > Math.sqrt(0.05 * 1.05) - 0.05 ? '#000000' : '#ffffff';
}

function paraLectura(color: string): string {
  const rgb = canales(color);
  // 7:1 sobre blanco deja margen para fondos neutros ligeramente sombreados.
  for (let mezcla = 1; mezcla > 0; mezcla -= 0.05) {
    const oscuro = rgb.map(valor => Math.floor(valor * mezcla));
    if (luminancia(oscuro) <= 1.05 / 7 - 0.05) return 'rgb(' + oscuro.join(', ') + ')';
  }
  return '#000000';
}

export function paletaPanel(tema: { principal: string; secundario: string }): Record<string, string> {
  return {
    '--tema-principal': tema.principal,
    '--tema-secundario': tema.secundario,
    '--tema-en-principal': textoSobre(tema.principal),
    '--tema-en-secundario': textoSobre(tema.secundario),
    '--tema-lectura': paraLectura(tema.principal),
    '--tema-acento': paraLectura(tema.secundario),
  };
}
