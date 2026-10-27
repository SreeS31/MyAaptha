'use client';

import { getCountries, getCountryCallingCode, parsePhoneNumberFromString, type CountryCode } from 'libphonenumber-js';
import { useMemo, useState } from 'react';
import countryNames from '../lib/country-names.json';

type Props = {
  value: string;
  onChange: (value: string) => void;
  required?: boolean;
  className?: string;
  placeholder?: string;
  ariaLabel?: string;
};

// One checked-in English inventory keeps SSR and browser ICU versions identical.
const countries = getCountries().map(code => ({
  code,
  name: (countryNames as Record<string,string>)[code] || code,
  callingCode: getCountryCallingCode(code),
})).sort((left, right) => {
  const a=left.name.normalize('NFKD').toLowerCase(), b=right.name.normalize('NFKD').toLowerCase();
  return a<b?-1:a>b?1:left.code<right.code?-1:left.code>right.code?1:0;
});

function initialCountry(value: string): CountryCode {
  return parsePhoneNumberFromString(value)?.country || 'IN';
}

function nationalDigits(value: string, country: CountryCode) {
  const parsed = parsePhoneNumberFromString(value);
  if (parsed?.country === country) return parsed.nationalNumber;
  const callingCode = getCountryCallingCode(country);
  return value.replace(/^\+/, '').replace(new RegExp(`^${callingCode}`), '').replace(/\D/g, '');
}

export default function CountryPhoneInput({ value, onChange, required = false, className = '', placeholder = 'Mobile number', ariaLabel = 'Mobile number' }: Props) {
  const [country, setCountry] = useState<CountryCode>(() => initialCountry(value));
  const [query, setQuery] = useState('');
  const digits = useMemo(() => nationalDigits(value, country), [value, country]);
  const callingCode = getCountryCallingCode(country);
  const selectedCountry = countries.find(item => item.code === country)!;
  const filteredCountries = countries.filter(item => `${item.name} ${item.callingCode}`.toLowerCase().includes(query.trim().toLowerCase()));

  const updateCountry = (next: CountryCode) => {
    setCountry(next);
    setQuery('');
    onChange(digits ? `+${getCountryCallingCode(next)}${digits}` : '');
  };

  const updateNumber = (input: string) => {
    const nextDigits = input.replace(/\D/g, '');
    onChange(nextDigits ? `+${callingCode}${nextDigits}` : '');
  };

  return <div className={`country-phone-input ${className}`}>
    <details className="country-code-select">
      <summary>{selectedCountry.name} (+{selectedCountry.callingCode})</summary>
      <div className="country-code-menu">
        <input type="search" value={query} onChange={event => setQuery(event.target.value)} placeholder="Search country or code" aria-label="Search country calling code"/>
        <div className="country-code-options">{filteredCountries.map(item => <button type="button" className={item.code === country ? 'selected' : ''} key={item.code} onClick={event => { updateCountry(item.code); event.currentTarget.closest('details')?.removeAttribute('open'); }}><span>{item.name}</span><strong>+{item.callingCode}</strong></button>)}</div>
      </div>
    </details>
    <input type="tel" inputMode="tel" required={required} value={digits} onChange={event => updateNumber(event.target.value)} placeholder={placeholder} aria-label={ariaLabel}/>
  </div>;
}
