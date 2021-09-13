import logo from "/assets/logo.png"; // see .parcelrc file for converting to logo.avif
// import logo from "/assets/logo.min.png"; // but image optimized by ./scripts/optimize-png much smaller 😉 (no transformation from parcel-plugin)
// import logo from './version'

document.body.append(typeof logo === "string" ? <img src={logo} /> : logo);
